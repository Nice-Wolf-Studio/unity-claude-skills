#!/bin/bash
# unity-ops/tests/permission-hook.sh — HARNESS-ONLY PreToolUse permission hook.  [T2.4b] [#28]
#
# WHY THIS EXISTS. Under `--permission-mode dontAsk` a `Bash(prefix*)` rule matches the LITERAL,
# PRE-EXPANSION command string, so `unity list --project-path "$PWD" …` matches NO rule — not even
# `Bash(unity *)`, and not even the rule that literally spells `Bash(unity list --project-path "$PWD"*)`.
# T2.4 proved that with four one-shot probes (results/unity-surface-preflight.md, issue #28). The
# `unity-surface-preflight` skill itself teaches `--arg p "$PWD"`, so every future rep would take a
# denial, be graded INCONCLUSIVE, and need an `-allow` re-run against unrestricted `Bash` — a
# cross-envelope comparison against the baselines. This hook changes the MATCHING MECHANISM, not the
# admitted SET: it re-implements run_scenario.sh's `ALLOW` array post-expansion-tolerantly.
#
# THIS FILE IS NOT PART OF THE PLUGIN. It is never staged (`stage.sh` copies only
# `.claude-plugin/`, `hooks/` and named `skills/<name>/` directories) and is passed to the child
# only through `--settings`, which run_scenario.sh generates at dispatch time.  [G18] [G20]
#
# CONTRACT
#   in : a PreToolUse payload on stdin.
#   out: for a Bash call whose EVERY segment is in the read-only set, one line of JSON on stdout
#        with hookSpecificOutput.permissionDecision == "allow". For anything else: NOTHING, exit 0,
#        which leaves normal permission evaluation in charge (and under `dontAsk` that is a deny).
#   THE HOOK NEVER RETURNS "deny". It can only ADMIT; it can never take away a rule's decision.
#   log: one JSONL line per Bash call in
#        ${XDG_STATE_HOME:-$HOME/.local/state}/unity-ops/permission-hook.jsonl
set -u

# --- Fail closed (= "pass", = denied by dontAsk) on no stdin and on no WORKING python3. The guard's
#     exit-code probe, not `command -v`: macOS ships a /usr/bin/python3 xcselect STUB.  [R4-E2] ---
INPUT=$(cat 2>/dev/null || true); [ -z "$INPUT" ] && exit 0
python3 -c 'pass' >/dev/null 2>&1 || exit 0

read -r -d '' UNITY_OPS_PERM_PY <<'PY' || true
import datetime, json, os, re, shlex, sys

SCAN_MAX  = 65536     # bytes of `command` that are EVALUATED
STORE_MAX = 2048      # bytes of `command` that are RECORDED

def nothing():        # never print, never fail: the absence of output IS the "no decision" answer
    sys.exit(0)

try:
    d = json.loads(sys.stdin.read())
except Exception:
    nothing()
if not isinstance(d, dict):
    nothing()
# 1. Not a Bash call -> no decision, no log line. Read/Grep/Skill/… keep their own rules.
if (d.get("tool_name") or "") != "Bash":
    nothing()

ti = d.get("tool_input") or {}
if not isinstance(ti, dict):
    ti = {}
cmd_raw = ti.get("command") or ""
if not isinstance(cmd_raw, str):
    cmd_raw = str(cmd_raw)
session = d.get("session_id") or ""

# ---------------------------------------------------------------- the read-only set
# Every entry below has a counterpart in run_scenario.sh's ALLOW array, or is a pure text filter a
# probe uses on its OWN output. Adding to this set WIDENS the envelope and needs the same scrutiny
# as adding a `Bash(...)` rule.
UNITY_SUB = {"--version", "--help", "status", "list", "command", "pipeline", "test", "build", "skill"}
UNITY_COMMAND_RO = {"editor_status", "list_open_scenes", "get_console_logs",
                    "get_scene_hierarchy", "get_editor_state"}
UNITY_DESTRUCTIVE_FLAGS = {"--yes", "--force", "--allow-install", "--confirm"}
GIT_SUB = {"status", "diff", "rev-parse", "log", "show"}
PLAIN = {"export", "cd", "pwd", "ls", "echo", "printf", "cat", "head", "tail", "grep", "wc",
         "tr", "sort", "uniq", "cut", "jq", "test", "[", "which", "true", "date",
         "basename", "dirname", "realpath"}
FIND_WRITES = {"-delete", "-exec", "-execdir", "-ok", "-okdir", "-fprint", "-fprintf", "-fls"}

ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
PUNCT  = "();<>|&"

def words_ok(words):
    """'' when this segment's command word is in the read-only set; else the reason it is not."""
    while words and ASSIGN.match(words[0]):     # leading `NAME=value` env-style assignments
        words = words[1:]
    if not words:
        return ""                               # assignments only: nothing is executed
    base = words[0].rsplit("/", 1)[-1]
    rest = words[1:]

    if base == "unity":
        if set(rest) & UNITY_DESTRUCTIVE_FLAGS:
            return "unity with an auto-confirm/destructive flag"
        if "--help" in rest or "-h" in rest:
            return ""                           # `unity <anything> --help` only prints help
        if not rest:
            return ""                           # bare `unity` prints its own help
        s1 = rest[0]
        if s1 not in UNITY_SUB:
            return "unity subcommand outside the read-only set: " + s1
        if s1 == "pipeline":
            if len(rest) < 2 or rest[1] != "list":
                return "unity pipeline: only `list` is read-only"
        elif s1 == "skill":
            if len(rest) < 2 or rest[1] != "install" or "--list" not in rest:
                return "unity skill: only `install --list` is read-only"
        elif s1 == "command":
            if len(rest) < 2 or rest[1] not in UNITY_COMMAND_RO:
                return "unity command: editor command outside the read-only set"
        return ""

    if base == "git":
        while len(rest) >= 2 and rest[0] == "-C":
            rest = rest[2:]
        if not rest:
            return "bare git"
        if rest[0] not in GIT_SUB:
            return "git subcommand outside the read-only set: " + rest[0]
        return ""

    if base in (".", "source"):
        if len(rest) != 1:
            return "source takes exactly one argument here"
        if rest[0].endswith("/.unity/env"):
            return ""
        return "source target is not the unity env file: " + rest[0]

    if base == "sed":
        if "-n" not in rest:
            return "sed without -n"
        for t in rest:
            if t.startswith("-i") or t == "--in-place":
                return "sed in-place edit"
        return ""

    if base == "awk":
        # awk can write files (`print > "f"`), pipe (`| "sh"`) and shell out (`system()`). Those
        # live INSIDE the quoted program token, where the tokenizer cannot see them as operators.
        for t in rest:
            if "system(" in t or ">" in t or "|" in t:
                return "awk program may redirect, pipe or shell out"
        return ""

    if base == "find":
        if set(rest) & FIND_WRITES:
            return "find with a writing/executing primary"
        return ""

    if base == "command":
        if rest and rest[0] in ("-v", "-V"):
            return ""
        return "command without -v"

    # Two entries of the read-only set carry a file-WRITE channel that owes nothing to a shell
    # redirection, so the redirection check above cannot see them. Narrowed here, at the command
    # word, rather than left to be discovered later:  `sort -o OUT`, and `uniq IN OUT`.
    if base == "sort":
        for t in rest:
            if t.startswith("-o") or t.startswith("--output"):
                return "sort -o writes a file"
        return ""
    if base == "uniq":
        # a `-f N` / `-s N` / `-w N` argument is an option value, not an operand
        skip, cleaned = False, []
        for t in rest:
            if skip:
                skip = False
                continue
            if t in ("-f", "-s", "-w", "--skip-fields", "--skip-chars", "--check-chars"):
                skip = True
                continue
            if not t.startswith("-"):
                cleaned.append(t)
        if len(cleaned) > 1:
            return "uniq with an output-file operand"
        return ""

    if base in PLAIN:
        return ""
    return "command word outside the read-only set: " + base

def check_segment(tokens):
    """'' when the segment is allowed; else the reason. Consumes redirections as it walks."""
    words, i, n = [], 0, len(tokens)
    while i < n:
        t = tokens[i]
        is_punct = bool(t) and all(ch in PUNCT for ch in t)
        if is_punct and ("<" in t or ">" in t):
            tgt = tokens[i + 1] if i + 1 < n else ""
            if words and words[-1].isdigit():
                words.pop()                              # the `2` of `2>&1` / `2>/dev/null`
            if t in (">&", "<&"):                        # file-descriptor duplication only
                if tgt.isdigit() or tgt == "-":
                    i += 2
                    continue
                return "fd redirection to a non-descriptor: " + (tgt or "<nothing>")
            if t in (">", ">>", "&>", "&>>") and tgt == "/dev/null":
                i += 2
                continue
            return "redirection " + t + " " + (tgt or "<nothing>")
        if is_punct:                                     # `(` / `)` grouping, subshells
            return "shell grouping token " + t
        words.append(t)
        i += 1
    return words_ok(words)

def normalize(text):
    """Quote-aware pre-pass: fold UNQUOTED newlines to ';' so a second line cannot ride along
       inside the first segment, and drop `\\<newline>` continuations. Returns (text, reason)."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == "\\" and i + 1 < n:
            if text[i + 1] != "\n":
                out.append(c); out.append(text[i + 1])
            i += 2
            continue
        if c == "'":
            j = text.find("'", i + 1)
            if j < 0:
                return None, "unterminated single quote"
            out.append(text[i:j + 1]); i = j + 1
            continue
        if c == '"':
            j, esc = i + 1, False
            while j < n:
                if esc:
                    esc = False
                elif text[j] == "\\":
                    esc = True
                elif text[j] == '"':
                    break
                j += 1
            if j >= n:
                return None, "unterminated double quote"
            out.append(text[i:j + 1]); i = j + 1
            continue
        out.append(";" if c == "\n" else c)
        i += 1
    return "".join(out), ""

SEPS = {";", "|", "||", "&&", "&", ";;", "|&", "&|"}

def evaluate(cmd):
    """'' when EVERY segment is allowed; else the first reason it is not."""
    if not cmd.strip():
        return "empty command"
    # Belt and braces, ahead of any parsing and regardless of quoting: command substitution is
    # opaque to this hook, so its mere presence disqualifies the whole command.
    if "$(" in cmd or "`" in cmd:
        return "command substitution in the command"
    body, why = normalize(cmd)
    if body is None:
        return why
    try:
        lex = shlex.shlex(body, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        # `#` must NOT start a comment here. shlex would drop the rest of the string, and because
        # newlines were folded to ';' above, `ls # note<newline>rm -rf /` would then look like the
        # single segment `ls` while bash runs line 2 for real. With no commenters, `#` is an
        # ordinary word character and the `rm` segment is seen and refused.
        lex.commenters = ""
        toks = list(lex)
    except ValueError as e:
        return "unparseable command (" + str(e) + ")"
    segs, cur = [], []
    for t in toks:
        if t in SEPS:
            segs.append(cur); cur = []
        else:
            cur.append(t)
    segs.append(cur)
    for seg in segs:
        if not seg:
            continue
        why = check_segment(seg)
        if why:
            return why
    return ""

if len(cmd_raw) > SCAN_MAX:
    reason = "command longer than %d bytes" % SCAN_MAX
else:
    reason = evaluate(cmd_raw)
allow = (reason == "")

# ---------------------------------------------------------------- the log
state = os.path.join(os.environ.get("XDG_STATE_HOME")
                     or os.path.join(os.path.expanduser("~"), ".local", "state"), "unity-ops")
# Same scenario mechanism the guard uses: run_scenario.sh writes `scenario.current` before the
# dispatch and removes it from a trap. There is no UNITY_OPS_SCENARIO variable (G18).
scen = os.environ.get("UNITY_OPS_SCENARIO", "")
if not scen:
    try:
        with open(os.path.join(state, "scenario.current")) as f:
            scen = f.read().replace("\n", "").replace("\r", "")[:120]
    except Exception:
        scen = ""
try:
    os.makedirs(state, exist_ok=True)
    with open(os.path.join(state, "permission-hook.jsonl"), "a") as f:
        f.write(json.dumps({
            "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "session_id": session, "scenario": scen,
            "command": cmd_raw[:STORE_MAX],
            "decision": "allow" if allow else "pass",
            "reason": "read-only set" if allow else reason,
        }, separators=(",", ":")) + "\n")
except Exception:
    pass

if allow:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "permissionDecisionReason": "unity-ops harness: read-only probe"}},
        separators=(",", ":")))
sys.exit(0)
PY
printf '%s' "$INPUT" | python3 -c "$UNITY_OPS_PERM_PY" 2>/dev/null || true
exit 0
