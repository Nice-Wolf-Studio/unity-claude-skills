#!/bin/bash
# unity-ops/tests/permission-hook.sh — HARNESS-ONLY PreToolUse permission hook.  [T2.4b] [#28]
#
# WHY THIS EXISTS. Under `--permission-mode dontAsk` a `Bash(prefix*)` rule matches the LITERAL,
# PRE-EXPANSION command string, so `unity list --project-path "$PWD" …` matches NO rule — not even
# `Bash(unity *)`, and not even the rule that literally spells `Bash(unity list --project-path "$PWD"*)`.
# T2.4 proved that with four one-shot probes (results/unity-surface-preflight.md, issue #28). The
# `unity-surface-preflight` skill itself teaches `--arg p "$PWD"`, so every future rep would take a
# denial, be graded INCONCLUSIVE, and need an `-allow` re-run against unrestricted `Bash` — a
# cross-envelope comparison against the baselines. This hook changes the MATCHING MECHANISM for the
# `unity` / `git` / `.` / `export` / `grep` prefixes `ALLOW` already encodes: it re-implements them
# post-expansion-tolerantly. The set is NOT identical to `ALLOW` — it also carries a short list of
# text filters that can neither write a file nor execute a program (a probe pipes its own output
# through them), and it does NOT carry `unity test` / `unity build`, which `ALLOW` still admits
# literally. See tests/README.md for the exact delta.
#
# ROUND-1 REVIEW (task-2.4b-review.md) closed here: awk/sed/find/sort/uniq dropped outright (they
# write files and shell out from INSIDE a quoted program token, where no tokenizer can see it);
# leading `NAME=value` assignments refused (GIT_EXTERNAL_DIFF/PATH/DYLD_* -> arbitrary execution);
# `export` narrowed to literal UNITY_* values; a git option denylist (-c, --output, --ext-diff, …);
# `unity skill install --list` made an EXACT token match.
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
# TWO KINDS OF ENTRY, and nothing else may be added without the same scrutiny as a `Bash(...)` rule:
#   (a) the `unity` / `git` / `.` / `export` / `grep` prefixes run_scenario.sh's ALLOW array already
#       encodes, made expansion-tolerant and, in several places, NARROWER than ALLOW;
#   (b) filters a probe runs over its OWN output that have NO option which writes a file or executes
#       a program: cat head tail wc tr cut basename dirname realpath echo printf pwd ls date true
#       test [ command which jq grep  (+ `cd`, which likewise cannot write or execute).
# DELIBERATELY ABSENT (round-1 review C1/H1/H2/M-sort): awk, sed, find, sort, uniq. Each has a
# documented channel that writes a file or runs a program from inside a token the tokenizer cannot
# inspect -- `awk 'BEGIN{system ("…")}'` (a space before the paren defeats any substring test),
# `sed -n 'w /path'` and `s///w`, `find -fprint0` (Claude Code's shell shadows find with bfs, which
# implements it), `sort --compress-program=`, `uniq IN OUT`. A probe uses grep/head/cut/jq or the
# Grep and Glob tools instead. ALSO ABSENT: `unity test` and `unity build` -- neither is read-only
# (a junit report, a build output), even though ALLOW still admits both LITERALLY.
UNITY_SUB = {"status", "list", "command", "pipeline", "skill"}   # --version/--help: exact forms only
UNITY_COMMAND_RO = {"editor_status", "list_open_scenes", "get_console_logs",
                    "get_scene_hierarchy", "get_editor_state"}
UNITY_DESTRUCTIVE_FLAGS = {"--yes", "--force", "--allow-install", "--confirm"}
UNITY_SKILL_TAIL = {"--format", "json", "--no-pager"}   # the ONLY tokens allowed after `--list`
GIT_SUB = {"status", "diff", "rev-parse", "log", "show"}
# git options that make git run a program or write a file without any shell redirection:
#   -c diff.external=… / --config-env  -> arbitrary program;  --exec-path, --git-dir, --work-tree
#   -> relocates what git executes / touches;  --output[=] -> writes a file;  --ext-diff, --textconv
#   -> invokes the configured external program;  -O/--orderfile -> reads an arbitrary file.
GIT_BAD = ("-c", "--config-env", "--exec-path", "--git-dir", "--work-tree",
           "--output", "--ext-diff", "--textconv", "-O", "-o", "--orderfile")
# jq cannot write a file, but these READ one, and the child is meant to stay on stdin/args. Matching
# is per-CHARACTER for short options, because `-nf /tmp/x` clusters `-n` with `-f` and does not start
# with `-f` (round-2 review R2-3). Survivors: -r -c -e -s -n -S -M -j -a -C --arg --argjson --args
# --jsonargs --tab --indent --raw-output --compact-output --null-input --sort-keys --slurp …
JQ_BAD_LONG = ("--rawfile", "--slurpfile", "--from-file", "--library-path", "--run-tests")
JQ_BAD_CHARS = "fL"      # -f/--from-file read the program; -L adds a module search path
PLAIN = {"cd", "pwd", "ls", "echo", "printf", "cat", "head", "tail", "grep", "wc",
         "tr", "cut", "test", "[", "which", "true", "date",
         "basename", "dirname", "realpath"}

ASSIGN     = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
EXPORT_OK  = re.compile(r"^UNITY_[A-Z0-9_]+=[^$`]*$")     # UNITY_* names, LITERAL values only
# EXACT matches only. An "absolute path ending /.unity/env" test admitted `. /tmp/evil/.unity/env`,
# and the child holds the unrestricted Write tool: Write that file, source it, arbitrary execution --
# the same chain shape as round-1 C2 (round-2 review R2-1). run_scenario.sh:132 sources exactly
# `. "$HOME/.unity/env"`, which posix shlex hands us as `$HOME/.unity/env`.
SOURCE_OK  = {"$HOME/.unity/env", "~/.unity/env", os.path.expanduser("~/.unity/env")}
# Read-only option tails (round-2 review R2-5). `--project-path`/`--timeout` take one value; `--format`
# takes `json` only; everything else after the subcommand is refused.
def tail_ok(tokens, verbose_ok):
    i, n = 0, len(tokens)
    while i < n:
        t = tokens[i]
        if t == "--project-path":
            if i + 1 >= n:
                return "--project-path without a value"
            i += 2; continue
        if t == "--format":
            if i + 1 >= n or tokens[i + 1] != "json":
                return "--format with a value other than json"
            i += 2; continue
        if t == "--timeout":
            if i + 1 >= n or not tokens[i + 1].isdigit():
                return "--timeout without a numeric value"
            i += 2; continue
        if t == "--no-pager" or (verbose_ok and t == "--verbose"):
            i += 1; continue
        return "argument outside the read-only option whitelist: " + t
    return ""
PUNCT  = "();<>|&"

def words_ok(words):
    """'' when this segment's command word is in the read-only set; else the reason it is not."""
    if not words:
        return ""
    # A leading `NAME=value` is REFUSED, not stripped (round-1 review C2/M-PATH/M-DYLD): it lets the
    # child set GIT_EXTERNAL_DIFF, PATH, DYLD_INSERT_LIBRARIES, BASH_ENV … and then run an ADMITTED
    # command, which is arbitrary execution with no `$(`, no redirection and no new command word.
    # The harness exports every UNITY_* variable a probe needs before the dispatch.
    if ASSIGN.match(words[0]):
        return "leading NAME=value assignment: " + words[0].split("=", 1)[0]
    # A PATH-QUALIFIED command word is refused outright. Matching on the basename admitted
    # `/tmp/evil/git status` and `./git status` (round-2 review R2-2): whatever sits at that path is
    # not the binary this set was reasoned about. `.` (the source builtin) has no slash and is unaffected.
    if "/" in words[0]:
        return "command word carries a path: " + words[0]
    base = words[0]
    rest = words[1:]

    if base == "unity":
        if set(rest) & UNITY_DESTRUCTIVE_FLAGS:
            return "unity with an auto-confirm/destructive flag"
        # `--help` must be the LAST token and nothing may follow it: `if "--help" in rest` admitted
        # `unity skill --help install /x` and `unity --help close` (round-2 review R2-4). ALLOW's rule
        # `Bash(unity * --help)` has no trailing `*`, so it too matches only commands ENDING in --help.
        if rest in (["--help"], ["-h"], ["--version"]):
            return ""
        if len(rest) in (2, 3) and rest[-1] == "--help":
            return ""                           # `unity <sub> [<sub2>] --help`
        if not rest:
            return ""                           # bare `unity` prints its own help
        s1 = rest[0]
        if s1 not in UNITY_SUB:
            return "unity subcommand outside the read-only set: " + s1
        if s1 in ("status", "list"):
            why = tail_ok(rest[1:], True)
            if why:
                return "unity " + s1 + ": " + why
        elif s1 == "pipeline":
            if len(rest) < 2 or rest[1] != "list":
                return "unity pipeline: only `list` is read-only"
            why = tail_ok(rest[2:], True)
            if why:
                return "unity pipeline list: " + why
        elif s1 == "skill":
            # EXACT token list. ALLOW's rule is the literal `Bash(unity skill install --list)`, which
            # cannot match a command carrying an install target; `unity skill install <t> --list`
            # must not be admitted by the hook either (round-1 review M2).
            if rest[:3] != ["skill", "install", "--list"]:
                return "unity skill: only the exact `skill install --list` form is read-only"
            for t in rest[3:]:
                if t not in UNITY_SKILL_TAIL:
                    return "unity skill install --list with an extra argument: " + t
        elif s1 == "command":
            if len(rest) < 2 or rest[1] not in UNITY_COMMAND_RO:
                return "unity command: editor command outside the read-only set"
            why = tail_ok(rest[2:], False)      # no --verbose here; the five names take no operands
            if why:
                return "unity command " + rest[1] + ": " + why
        return ""

    if base == "git":
        for t in rest:
            if t.startswith(GIT_BAD):
                return "git option that can execute or write: " + t
        if rest[:1] == ["-C"]:                  # the form is `git [-C <path>] <sub> [args]`
            if len(rest) < 2:
                return "git -C without a path"
            rest = rest[2:]
        if not rest:
            return "bare git"
        if rest[0] not in GIT_SUB:
            return "git subcommand outside the read-only set: " + rest[0]
        return ""

    if base in (".", "source"):
        if len(rest) != 1:
            return "source takes exactly one argument here"
        t = rest[0]
        if t in SOURCE_OK:
            return ""
        return "source target is not the unity env file: " + t

    if base == "export":
        # UNITY_* names with literal values only. `export PATH=…` / `export GIT_EXTERNAL_DIFF=…` is
        # the same arbitrary-execution channel as a leading assignment; bare `export NAME` exports
        # whatever that name was set to elsewhere.
        if not rest:
            return "bare export"
        for t in rest:
            if not EXPORT_OK.match(t):
                return "export outside UNITY_*=<literal value>: " + t
        return ""

    if base == "jq":
        for t in rest:
            if not t.startswith("-") or t == "-" or t == "--":
                continue                        # a filter or an operand, not an option
            if t.startswith(JQ_BAD_LONG):
                return "jq option that reads an arbitrary file: " + t
            if not t.startswith("--"):           # short-option cluster: check every character
                for ch in t[1:]:
                    if ch in JQ_BAD_CHARS:
                        return "jq short option that reads an arbitrary file: " + t
        return ""

    if base == "command":
        if rest and rest[0] in ("-v", "-V"):
            return ""
        return "command without -v"             # `command rm -rf x` RUNS rm

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
