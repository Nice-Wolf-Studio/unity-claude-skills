#!/bin/bash
# unity-ops/tests/run_scenario.sh — the ONLY way a scenario is dispatched.  [R3-7] [R3-4] [R3-5]
# Usage: bash unity-ops/tests/run_scenario.sh <tag> <prompt> <transcript-path>
# Exit: 0 ok | 2 refused (another run in progress, or a stale flag)
#       3 PRECONDITION_FAILED (not logged in) | 4 PRECONDITION_FAILED (no session_id in transcript)
set -u
TAG="${1:?tag}"; PROMPT="${2:?prompt}"; T="${3:?transcript path}"
ST="${XDG_STATE_HOME:-$HOME/.local/state}/unity-ops"; mkdir -p "$ST"
FLAG="$ST/scenario.current"; LOCK="$ST/scenario.lock"
HAVE_LOCK=0; child=""

cleanup() {
  if [ "$HAVE_LOCK" = 1 ]; then rm -f "$FLAG" "$LOCK/pid"; rmdir "$LOCK" 2>/dev/null || true; fi
}
# --- 0. Traps are installed BEFORE the lock is taken.  [R4-M1] [R4-SIGTERM]
# Bash DEFERS a trap while it is blocked on a FOREGROUND child, so the dispatch below runs in
# the BACKGROUND and the script blocks in `wait` — which a signal does interrupt. Without that,
# a SIGTERM during a 20-minute `claude -p` left the flag and the lock in place for its whole
# remaining life, and every record written anywhere on the machine was tagged with this scenario.
trap 'kill -TERM "$child" 2>/dev/null; cleanup; exit 143' TERM
trap 'kill -TERM "$child" 2>/dev/null; cleanup; exit 130' INT
trap 'kill -TERM "$child" 2>/dev/null; cleanup; exit 129' HUP
trap cleanup EXIT

# --- 1. Mutual exclusion. `mkdir` is atomic; the pid is written in the SAME && chain, so the
#        window in which a lock exists with no owner recorded is as small as the shell allows,
#        and a lock that lands in that window anyway is recovered by age below.  [R4-M1] ---
if mkdir "$LOCK" 2>/dev/null && echo $$ > "$LOCK/pid"; then
  HAVE_LOCK=1
else
  OWNER=$(cat "$LOCK/pid" 2>/dev/null || true); STALE=0; REASON=""
  if [ -n "$OWNER" ] && ! kill -0 "$OWNER" 2>/dev/null; then
    STALE=1; REASON="dead pid $OWNER"
  elif [ -z "$OWNER" ] && [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
    # A lock directory with NO pid file that is older than 60 s can only be a dispatch killed
    # between `mkdir` and the pid write. Recover it, and say so.  [R4-M1]
    STALE=1; REASON="no pid file and the lock is older than 60 s"
  fi
  if [ "$STALE" = 1 ]; then
    echo "run_scenario: clearing a stale lock ($REASON)" >&2
    rm -f "$LOCK/pid" "$FLAG"; rmdir "$LOCK" 2>/dev/null || true
    if mkdir "$LOCK" 2>/dev/null && echo $$ > "$LOCK/pid"; then HAVE_LOCK=1
    else echo "run_scenario: another scenario run is in progress" >&2; exit 2; fi
  else
    echo "run_scenario: another scenario run is in progress (pid ${OWNER:-?}, tag $(cat "$FLAG" 2>/dev/null || true))" >&2
    exit 2
  fi
fi

# --- 2. The flag must be ABSENT before a dispatch. A leftover tags every real record forever. ---
if [ -e "$FLAG" ]; then echo "run_scenario: stale flag $FLAG present; refusing" >&2; exit 2; fi

# --- 3. Auth, re-checked PER REP: an OAuth session can expire mid-batch.  [R3-5]
#        `claude auth status` EXITS 1 when logged out, so it is tolerated explicitly before the
#        pipe rather than left to take the script down under any future `set -e`.  [R4-SIGTERM] ---
if [ "${UNITY_OPS_DRYRUN:-0}" != 1 ]; then
  { claude auth status 2>/dev/null || true; } | python3 -c 'import json,sys
try: sys.exit(0 if json.load(sys.stdin).get("loggedIn") is True else 1)
except Exception: sys.exit(1)' \
  || { echo "PRECONDITION_FAILED: claude auth status reports no logged-in session (rep $TAG)" >&2; exit 3; }
fi

printf '%s' "$TAG" > "$FLAG"
rm -f "${T%.json}.session"      # never leave a previous run's id beside a new transcript

# --- 4. Dispatch, IN THE BACKGROUND, then block in `wait`. Explicit permission envelope so a
#        denied probe cannot read as RED.  [R3-4] [R4-F3] ---
# The rules contain SPACES and GLOB characters — `Bash(unity status*)` is ONE rule — so they must
# be an ARRAY. As an unquoted string they were word-split into fragments AND pathname-expanded
# against the dispatch cwd (~/Dev/Unity/ai_test), producing 48 junk tokens including that project's
# own directory names and leaving NO `Bash(...)` rule intact — so every `unity` probe came back
# DENIED and a denied probe reads as RED, which is the exact failure [R3-4] this envelope exists to
# prevent. An override in UNITY_OPS_ALLOW is therefore NEWLINE-separated, one rule per line.  [T1.3]
if [ -n "${UNITY_OPS_ALLOW:-}" ]; then
  ALLOW=(); while IFS= read -r _r; do [ -n "$_r" ] && ALLOW+=("$_r"); done <<< "$UNITY_OPS_ALLOW"
else
  # `Task` is this CLI's subagent tool (2.1.270 lists it in the init envelope, not `Agent`);
  # both are named so the envelope permits a subagent dispatch whichever the build exposes.  [T1.3]
  ALLOW=(Read Grep Glob Write Edit Skill Agent Task \
         "Bash(. *)" "Bash(export *)" "Bash(grep *)" \
         "Bash(unity --version)" "Bash(unity --help)" "Bash(unity * --help)" \
         "Bash(unity skill install --list)" "Bash(unity status*)" "Bash(unity list*)" \
         "Bash(unity command*)" "Bash(unity pipeline list*)" "Bash(unity test*)" \
         "Bash(unity build*)" "Bash(git status*)" "Bash(git diff*)")
fi
FMT="${UNITY_OPS_FORMAT:-json}"
# Every scenario child runs on Sonnet unless UNITY_OPS_MODEL overrides it (execution directive, 2026-09-14):
# a skill that holds Sonnet under pressure holds Opus. Verified: `claude -p --model sonnet` accepted on 2.1.270.
if [ "${UNITY_OPS_DRYRUN:-0}" = 1 ]; then
  ( exec sleep "${UNITY_OPS_DRYSLEEP:-2}" ) & child=$!
  wait "$child"; RC=$?; child=""
  [ "$RC" = 0 ] && cp "${UNITY_OPS_DRYTRANSCRIPT:-/dev/null}" "$T"
else
  ( cd ~/Dev/Unity/ai_test && \
    UNITY_TEST_TIMEOUT=600 UNITY_BUILD_TIMEOUT=1800 UNITY_RUN_TIMEOUT=600 \
    exec claude -p --plugin-dir /tmp/unity-ops-stage --output-format "$FMT" --verbose \
      --model "${UNITY_OPS_MODEL:-sonnet}" \
      --permission-mode dontAsk --allowedTools "${ALLOW[@]}" \
      -- "$PROMPT" < /dev/null ) > "$T" &
  child=$!
  wait "$child"; RC=$?; child=""
fi

# --- 5. The run's OWN session id -> <transcript>.session. Primary metric filter.  [R3-7]
#        An EMPTY .session file is worse than none: metrics.md would build an empty regex
#        alternative out of it and exclude every record in the log. Exit 4 instead.  [R4-M2] ---
python3 - "$T" "${T%.json}.session" <<'PY'
import json, pathlib, sys
raw = pathlib.Path(sys.argv[1]).read_text(errors="replace")
def envs(t):
    try: d = json.loads(t)
    except Exception:
        for l in t.splitlines():
            l = l.strip()
            if l:
                try: yield json.loads(l)
                except Exception: pass
        return
    yield from (d if isinstance(d, list) else [d])
sid = ""
for e in envs(raw):
    if isinstance(e, dict) and e.get("session_id"): sid = str(e["session_id"]).strip(); break
if not sid:
    print("PRECONDITION_FAILED: no session_id in transcript " + sys.argv[1], file=sys.stderr)
    sys.exit(4)
pathlib.Path(sys.argv[2]).write_text(sid + "\n")
print("session_id:", sid)
PY
SRC=$?
[ "$SRC" -ne 0 ] && exit "$SRC"
exit $RC
