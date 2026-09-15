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
# T4.0 — THE ONE SET IN HERE THAT IS NOT READ-ONLY. Five `unity command` names that CHANGE EDITOR
# STATE (`create_gameobject`, `set_transform`, `find_gameobjects`, `save_scene`, `save_all`) are
# admitted, and ONLY when the hook process's own realpath'd cwd IS `~/Dev/Unity/ai_test` AND any
# `--project-path` resolves to that same directory. Outside the testbed they are refused exactly as
# before. `UNITY_COMMAND_RO` is untouched; `open_scene`, `add_component`, `undo`, `delete_*`,
# `create_gameobjects`, `eval*`, `unity close` and `unity open` stay refused. See "the TESTBED
# LIVE-EDIT set" below and tests/README.md for the rationale and the option whitelist.
#
# THIS FILE IS NOT PART OF THE PLUGIN. It is never staged (`stage.sh` copies only
# `.claude-plugin/`, `hooks/` and named `skills/<name>/` directories) and is passed to the child
# only through `--settings`, which run_scenario.sh generates at dispatch time.  [G18] [G20]
#
# CONTRACT
#   in : a PreToolUse payload on stdin.
#   out: for a Bash call whose EVERY segment is in the read-only set (or, inside the testbed, in the
#        T4.0 live-edit set), one line of JSON on stdout with
#        hookSpecificOutput.permissionDecision == "allow". For anything else: NOTHING, exit 0,
#        which leaves normal permission evaluation in charge (and under `dontAsk` that is a deny).
#        A compound command is ALL-OR-NOTHING: one refused segment refuses the whole command.
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
UNITY_SUB = {"status", "list", "command", "pipeline", "skill", "vcs"}   # --version/--help: exact forms only
UNITY_COMMAND_RO = {"editor_status", "list_open_scenes", "get_console_logs",
                    "get_scene_hierarchy", "get_editor_state"}
# ---------------------------------------------------------------- the TESTBED LIVE-EDIT set  [T4.0]
# A SECOND, SEPARATE set. `UNITY_COMMAND_RO` above is unchanged and still means "read-only, anywhere".
# The five names below CHANGE EDITOR STATE. They are admitted only when BOTH conditions hold:
#   (1) the hook process's OWN cwd (os.getcwd(), realpath'd) is the calibration testbed. That cwd
#       comes from run_scenario.sh's `cd ~/Dev/Unity/ai_test` at dispatch; nothing in the command
#       string can move it, and no model text is consulted for it.
#   (2) `--project-path`, WHEN PRESENT, resolves to that same directory. `~`, `$HOME`, `$PWD`, `.`
#       and the literal absolute path all resolve (the hook sees the PRE-expansion token, #28); a
#       literal path anywhere else is refused -> `pass`.
# WHY THE WIDENING EXISTS. The Increment 4 scenario `unity-live-edit-verification` has its child
# create GameObjects, set their transforms, read them back with `find_gameobjects` and save. Under
# `dontAsk` the literal `Bash(unity command*)` rule never matches a command carrying `"$PWD"` (#28),
# so without this even the COMPLIANT read-back path is unreachable and every rep grades INCONCLUSIVE.
# DELIBERATELY OUT, all still `pass`: `open_scene` (it is the scenario's RESET — a child that can
# re-open a scene can discard the state the scenario grades, and the reset belongs to the runner),
# `add_component`, `undo`, every `delete_*`, `create_gameobjects` (its `--name` is a BASE name that
# suffixes `Name1..NameN`, so it cannot produce the scenario's three names), `eval`/`eval_file`/
# `report_evals`, `unity close`, `unity open`. Membership is EXACT: no prefix match, no plural.
UNITY_TESTBED = "/Users/jeremymiranda/Dev/Unity/ai_test"
UNITY_LIVE_EDIT = {"create_gameobject", "set_transform", "find_gameobjects",
                   "save_scene", "save_all"}
# Parameter names taken VERBATIM from the tool catalog --
# `unity list --project-path <testbed> --format json --no-pager` -> data.tools[].parameters[].name
# (151 tools, read 2026-09-15). NOT from `--help`: `unity command <name> --help` prints the ROOT help
# for every one of these (T4.1 §3), so the catalog is the only authority for these spellings.
# NOTE `set_transform` takes `--target`, NOT `--name`; its three channels are `--position` /
# `--rotation` / `--scale`, each typed `single[]` ("Local position as [x,y,z]").
UNITY_LIVE_EDIT_PARAMS = {
    "create_gameobject": frozenset({"name", "primitive", "parent"}),
    "set_transform":     frozenset({"target", "position", "rotation", "scale"}),
    "find_gameobjects":  frozenset({"name", "tag", "type", "hierarchy_path", "include_inactive"}),
    "save_scene":        frozenset({"path"}),
    "save_all":          frozenset(),
}
# The `single[]` channels. The catalog gives the TYPE, not the CLI spelling, and confirming the
# spelling requires mutating the scene (T4.1 concern 2 -- T4.2's first rep is the first sanctioned
# mutation). The value rule is therefore a character class wide enough for every plausible spelling
# (`1,2,3`, `[1,2,3]`, `{"x":1,"y":2,"z":3}`) and narrow enough that NO expansion of such a token can
# produce a `/`, a `$`, a `*`/`?`, or any option name: the class carries no slash and no letter but
# x/y/z, so brace/bracket expansion of it can only ever yield more characters from the same class.
# It is also the ONE place a value may start with `-`: `--position -4,0,3` and the space-separated
# `--position -4 0 3` are ordinary negative coordinates, and refusing them would make every mutation
# rep INCONCLUSIVE -- the failure this whole hook exists to prevent. `--position -rf` is still
# refused, because `r`/`f` are outside the class.
UNITY_LIVE_EDIT_VECTOR = frozenset({"position", "rotation", "scale"})
VECTOR_OK = re.compile(r'^[-+0-9.,\[\]{}":xyzXYZ ]+$')
# Global options admitted on top of the per-command parameters. No `--help` (a `--help` admission on
# a MUTATING verb is exactly what round-4 F4-1 closed), no `--no-banner`/`--non-interactive`/
# `--quiet`, no `--proxy`/`--log-proxy`, no `-V`. `--json` is this CLI's bare shorthand for
# `--format json` (`unity command --help`, Global Options) -- it takes no payload.
UNITY_LIVE_EDIT_FLAGS = frozenset({"--json", "--no-pager", "--verbose"})
# Set when a live-edit admission is what carried the command, so the log line names the right set.
LIVE_EDIT = [False]
# Where the segment under examination sits in the whole command. The live-edit set is admitted only
# as the LAST segment, preceded by nothing but a prelude (`. "$HOME/.unity/env"` / `export UNITY_*=`)
# -- and by nothing at all when `--project-path` is absent, because then the hook's cwd is the only
# thing standing in for the shell's.  [round-6 review F6-1]
SEG_CTX = {"nothing_before": True, "prelude_before": True, "nothing_after": True}
UNITY_DESTRUCTIVE_FLAGS = {"--yes", "--force", "--allow-install", "--confirm"}
UNITY_SKILL_TAIL = {"--format", "json", "--no-pager"}   # the ONLY tokens allowed after `--list`
# `unity vcs affected [path] [options]` — read-only reporting (T3.1). Flags that take no value
# and are safe to admit expansion-tolerantly; `--since`/`--format`/`--timeout` are checked separately
# below because they take a value. Deliberately absent: `--proxy`/`--log-proxy` (network / writes
# proxy-request.json), `--proxy-disable`/`--no-log-proxy` (not in the admit list either), `-V`.
UNITY_VCS_AFFECTED_FLAGS = {"--json", "--no-pager", "--no-banner", "--non-interactive", "--quiet",
                            "--verbose"}
# The second words that make an ADMITTED prefix, for the depth-3 `unity <sub> <sub2> --help` form.
# The review named `vcs` and `command`; `pipeline install --help` and `skill`/`status`/`list` are the
# same shape (`pipeline install` is as mutating as `vcs commit`), so the rule is uniform rather than
# a list of the two spellings that happened to be reported.  [round-4 review F4-1]
UNITY_SUB2_OK = {"vcs": {"affected"}, "command": UNITY_COMMAND_RO,
                 "pipeline": {"list"}, "skill": {"install"}}
# `unity <sub> --help` prints a help screen; it does not run <sub>. `test` and `build` are NOT in the
# read-only set -- executing either writes (a junit report, a build output) -- but their HELP is
# read-only, and `unity test --help | grep -i affected` is the unity-cli-contract scenario's primary
# qualifying probe. Help-only, therefore: `unity test` and `unity build` themselves still pass, and
# ALLOW admits their literal spellings by the --allowedTools route.  [T3.1]
UNITY_HELP_SUB = UNITY_SUB | {"test", "build"}
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
# `cd` was in this set from round 1, when nothing in the set could write and the review judged it
# harmless -- correctly, then. T4.0 invalidated that: the live-edit set's blast radius is a function
# of cwd, and a `cd` segment moves the COMMAND's shell while the hook's own cwd predicate cannot
# move, so `cd /tmp && unity command save_all` was admitted and two other real Unity projects live
# under ~/Dev/Unity/ (round-6 review F6-1). `pushd`/`popd` were never in the set. A scenario child
# starts in the testbed and has no need to move.
PLAIN = {"pwd", "ls", "echo", "printf", "cat", "head", "tail", "grep", "wc",
         "tr", "cut", "test", "[", "which", "true", "date",
         "basename", "dirname", "realpath"}

ASSIGN     = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
EXPORT_OK  = re.compile(r"^UNITY_[A-Z0-9_]+=[^$`]*$")     # UNITY_* names, LITERAL values only
# EXACT matches only. An "absolute path ending /.unity/env" test admitted `. /tmp/evil/.unity/env`,
# and the child holds the unrestricted Write tool: Write that file, source it, arbitrary execution --
# the same chain shape as round-1 C2 (round-2 review R2-1). run_scenario.sh:132 sources exactly
# `. "$HOME/.unity/env"`, which posix shlex hands us as `$HOME/.unity/env`.
SOURCE_OK  = {"$HOME/.unity/env", "~/.unity/env", os.path.expanduser("~/.unity/env")}
# A path VALUE the hook accepts must be one path to bash as well as one token to the hook. A glob
# metacharacter makes it many words after expansion, and a file named like an option (`--log-proxy`)
# then arrives as an OPTION, past the whitelist — the child can author such a file with the
# unrestricted Write tool (round-4 review F4-2). `..` segments are refused with it: nothing read-only
# in this harness needs to climb out of the directory it was pointed at.
def path_ok(v):
    if v == "":
        return "empty path value"
    for ch in "*?[":
        if ch in v:
            return "path with a glob metacharacter: " + v
    if ".." in v.split("/"):
        return "path with a .. segment: " + v
    return ""

# ---------------------------------------------------------------- live-edit scoping  [T4.0]
HOME = os.path.expanduser("~")
try:
    TESTBED_REAL = os.path.realpath(UNITY_TESTBED)
except Exception:
    TESTBED_REAL = UNITY_TESTBED
try:
    HOOK_CWD = os.path.realpath(os.getcwd())
except Exception:
    HOOK_CWD = ""

def is_prelude(seg):
    """A segment that may legitimately precede a live-edit command: sourcing the unity env file, or
       exporting a UNITY_* literal. Both are already admitted on their own terms; neither can change
       the shell's cwd, which is the property the live-edit scoping depends on."""
    if not seg:
        return True
    w = seg[0]
    if w in (".", "source"):
        return len(seg) == 2 and seg[1] in SOURCE_OK
    if w == "export":
        return len(seg) >= 2 and all(EXPORT_OK.match(t) for t in seg[1:])
    return False

def in_testbed():
    """Condition (1): the hook PROCESS's own cwd is the testbed. Resolved once, from os.getcwd(),
       never from the command string -- a model cannot write its way into this predicate."""
    return bool(HOOK_CWD) and HOOK_CWD == TESTBED_REAL

def resolves_to_testbed(v):
    """Condition (2): a `--project-path` VALUE names the testbed. The hook sees the PRE-expansion
       token (#28), so `$PWD`, `${PWD}`, `$HOME`, `${HOME}` and a leading `~` are resolved here the
       way bash would, and a relative value (`.`) resolves against the hook's cwd. Any `$`/`~` left
       after that is an expansion this hook cannot resolve -> not the testbed."""
    s = v
    if s == "~":
        s = HOME
    elif s.startswith("~/"):
        s = HOME + s[1:]
    else:
        for var, val in (("${PWD}", HOOK_CWD), ("$PWD", HOOK_CWD),
                         ("${HOME}", HOME), ("$HOME", HOME)):
            if s == var:
                s = val
                break
            if s.startswith(var + "/"):
                s = val + s[len(var):]
                break
    if not s or "$" in s or "~" in s:
        return False
    if not os.path.isabs(s):
        s = os.path.join(HOOK_CWD or "/", s)
    try:
        return os.path.realpath(s) == TESTBED_REAL
    except Exception:
        return False

def value_ok(v):
    """A non-vector, non-path live-edit option VALUE. One token to the hook must be one word to bash
       and must not be able to arrive as an OPTION: refused are a leading `-`, a leading `~`, any
       `$`, the brace-expansion characters `{`/`}`, the glob metacharacters `*`/`?`/`[` and any `..`
       segment (F4-2 -- the child holds the unrestricted Write tool and can author a file named
       `--project-path`, which a glob would then hand to the CLI as a real option)."""
    if v == "":
        return "empty option value"
    if v.startswith("-"):
        return "option value that starts with -: " + v
    if v.startswith("~"):
        return "option value with a leading ~: " + v
    if "$" in v:
        return "option value carrying a shell expansion: " + v
    for ch in "{}":
        if ch in v:
            return "option value with a brace-expansion character: " + v
    return path_ok(v)

def vector_ok(v):
    """`--position` / `--rotation` / `--scale`. See UNITY_LIVE_EDIT_VECTOR."""
    if not v or not VECTOR_OK.match(v):
        return "vector value outside the numeric/bracket character class: " + v
    for ch in "{}":
        # `--position {1..3}` matches the character class and bash expands it to THREE words;
        # `{a,b}` is the same machinery. Refusing the braces costs the `{"x":1,"y":2,"z":3}` JSON
        # spelling, which no rep has ever been observed using.  [round-6 review F6-3]
        if ch in v:
            return "vector value with a brace-expansion character: " + v
    if not any(c.isdigit() for c in v):
        return "vector value with no digit: " + v
    return ""

def save_path_ok(v):
    """`save_scene --path` is the ONE value in this set that decides where bytes land on disk, so it
       takes `value_ok` (glob, `..`, `$`, braces, leading `-`) AND must be a RELATIVE path under
       `Assets/`. `Assets/../../x.unity`, `/tmp/x.unity` and `Assets/*.unity` are all refused."""
    why = value_ok(v)
    if why:
        return why
    if v.startswith("/"):
        return "save_scene --path must be relative, not absolute: " + v
    if not v.startswith("Assets/"):
        return "save_scene --path outside Assets/: " + v
    if not v.endswith(".unity"):
        # Writing scene YAML over `SampleScene.unity.meta` corrupts an asset's GUID binding, and a
        # reviewer reading a GATE diff would not recognise it as that.  [round-6 review F6-2]
        return "save_scene --path does not end in .unity: " + v
    return ""

def live_edit_tail_ok(name, tokens):
    """Everything after `unity command <live-edit name>`. Per-command parameter names come from the
       catalog (UNITY_LIVE_EDIT_PARAMS) and each takes exactly one value; on top of them only the
       global options in UNITY_LIVE_EDIT_FLAGS plus `--project-path`, `--format json` and
       `--timeout <digits>`. Both the SPACED and the GLUED (`--name=X`) spellings, same validation
       (F4-3). No positional operand, no `--help`, no unknown option."""
    params = UNITY_LIVE_EDIT_PARAMS[name]
    i, n = 0, len(tokens)
    while i < n:
        t = tokens[i]
        if t == "--project-path" or t.startswith("--project-path="):
            if t.startswith("--project-path="):
                val, step = t.split("=", 1)[1], 1
            elif i + 1 < n:
                val, step = tokens[i + 1], 2
            else:
                return "unity command " + name + ": --project-path without a value"
            why = path_ok(val)
            if why:
                return "unity command " + name + ": --project-path: " + why
            if not resolves_to_testbed(val):
                return ("unity command " + name
                        + ": --project-path does not resolve to the testbed: " + val)
            i += step
            continue
        if t == "--format" or t.startswith("--format="):
            if t.startswith("--format="):
                if t != "--format=json":
                    return "unity command " + name + ": --format with a value other than json"
                i += 1
            else:
                if i + 1 >= n or tokens[i + 1] != "json":
                    return "unity command " + name + ": --format with a value other than json"
                i += 2
            continue
        if t == "--timeout" or t.startswith("--timeout="):
            if t.startswith("--timeout="):
                val, step = t.split("=", 1)[1], 1
            else:
                val, step = (tokens[i + 1] if i + 1 < n else ""), 2
            if not (val.isascii() and val.isdigit()):
                return "unity command " + name + ": --timeout without a numeric value"
            i += step
            continue
        if t in UNITY_LIVE_EDIT_FLAGS:
            i += 1
            continue
        if t.startswith("--"):
            key, eq, glued = t[2:].partition("=")
            if key not in params:
                return ("unity command " + name
                        + ": option outside the catalog parameter list: " + t)
            if eq:
                val, step = glued, 1
            elif i + 1 < n:
                val, step = tokens[i + 1], 2
            else:
                return "unity command " + name + ": " + t + " without a value"
            if key in UNITY_LIVE_EDIT_VECTOR:
                why = vector_ok(val)
            elif name == "save_scene" and key == "path":
                why = save_path_ok(val)
            else:
                why = value_ok(val)
            if why:
                return "unity command " + name + " --" + key + ": " + why
            i += step
            # A `single[]` channel may also arrive SPACE-separated -- `--position -4 0 3` -- so keep
            # consuming while the NEXT token is itself a bare vector literal. Negative coordinates
            # are certain to appear and a leading `-` is what `value_ok` refuses, which is why the
            # vector channels take `vector_ok` instead. Nothing else is consumed: the next `--option`
            # ends the run, and a consumed token can only ever be a number-shaped literal -- never an
            # option name and never a path, because VECTOR_OK carries no slash and no letter but
            # x/y/z. `--position -rf` and `--position id` stop here and are refused below.  [T4.0]
            if key in UNITY_LIVE_EDIT_VECTOR:
                while i < n and not tokens[i].startswith("--") and vector_ok(tokens[i]) == "":
                    i += 1
            continue
        return "unity command " + name + ": argument outside the live-edit whitelist: " + t
    return ""

# Read-only option tails (round-2 review R2-5). `--project-path`/`--timeout` take one value; `--format`
# takes `json` only; everything else after the subcommand is refused. Both the SPACED (`--format json`)
# and the GLUED (`--format=json`) spellings are accepted, with identical value validation: the CLI's
# own `--help` output may teach either, and refusing one of them re-creates the INCONCLUSIVE grading
# this whole hook exists to prevent (round-4 review F4-3).
def tail_ok(tokens, verbose_ok):
    i, n = 0, len(tokens)
    while i < n:
        t = tokens[i]
        if t.startswith("--project-path="):
            why = path_ok(t.split("=", 1)[1])
            if why:
                return "--project-path=: " + why
            i += 1; continue
        if t == "--project-path":
            if i + 1 >= n:
                return "--project-path without a value"
            why = path_ok(tokens[i + 1])
            if why:
                return "--project-path: " + why
            i += 2; continue
        if t.startswith("--format="):
            if t != "--format=json":
                return "--format with a value other than json"
            i += 1; continue
        if t == "--format":
            if i + 1 >= n or tokens[i + 1] != "json":
                return "--format with a value other than json"
            i += 2; continue
        if t.startswith("--timeout="):
            if not t.split("=", 1)[1].isdigit():
                return "--timeout without a numeric value"
            i += 1; continue
        if t == "--timeout":
            if i + 1 >= n or not tokens[i + 1].isdigit():
                return "--timeout without a numeric value"
            i += 2; continue
        if t == "--no-pager" or (verbose_ok and t == "--verbose"):
            i += 1; continue
        return "argument outside the read-only option whitelist: " + t
    return ""
# `unity vcs affected` tail: at most one positional path, `--since <ref>` (value must not itself look
# like an option — `--since -x` is refused, matching `--timeout`'s "must be a value" shape), and the
# no-value flags in UNITY_VCS_AFFECTED_FLAGS. `--help`/`-h` is admitted ONLY as the sole trailing
# token — mixed with anything else it is refused, same posture as `--help` elsewhere in this file.
def vcs_affected_tail_ok(tokens):
    if tokens == ["--help"] or tokens == ["-h"]:
        return ""
    took_positional = False
    i, n = 0, len(tokens)
    while i < n:
        t = tokens[i]
        if t in ("--help", "-h"):
            return "unity vcs affected: --help/-h admitted only as the sole trailing token"
        if t.startswith("--since="):              # glued spelling, same validation (F4-3)
            val = t.split("=", 1)[1]
            if val == "" or val.startswith("-"):
                return "unity vcs affected: --since= with an empty or option-like value: " + t
            i += 1; continue
        if t == "--since":
            if i + 1 >= n:
                return "unity vcs affected: --since without a value"
            val = tokens[i + 1]
            if val.startswith("-"):
                return "unity vcs affected: --since with a value that starts with -: " + val
            i += 2; continue
        if t.startswith("--format="):
            if t != "--format=json":
                return "unity vcs affected: --format with a value other than json"
            i += 1; continue
        if t == "--format":
            if i + 1 >= n or tokens[i + 1] != "json":
                return "unity vcs affected: --format with a value other than json"
            i += 2; continue
        if t.startswith("--timeout="):
            if not t.split("=", 1)[1].isdigit():
                return "unity vcs affected: --timeout without a numeric value"
            i += 1; continue
        if t == "--timeout":
            if i + 1 >= n or not tokens[i + 1].isdigit():
                return "unity vcs affected: --timeout without a numeric value"
            i += 2; continue
        if t in UNITY_VCS_AFFECTED_FLAGS:
            i += 1; continue
        if t.startswith("-"):
            return "unity vcs affected: argument outside the read-only option whitelist: " + t
        if took_positional:
            return "unity vcs affected: more than one positional argument: " + t
        why = path_ok(t)                          # one token here must be one path to bash too (F4-2)
        if why:
            return "unity vcs affected: " + why
        took_positional = True
        i += 1
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
        # The depth-2/3 form must name an ADMITTED prefix. `len(rest) in (2,3) and rest[-1]=="--help"`
        # sat ABOVE the subcommand dispatch and returned before `s1 not in UNITY_SUB` was ever
        # evaluated, so it admitted `unity vcs commit --help`, `unity vcs push --help` and
        # `unity command save_all --help` — mutating verbs, on the standing (still unverified)
        # assumption that `--help` short-circuits execution in this CLI (round-4 review F4-1).
        # `rest[0] in UNITY_SUB` alone is NOT sufficient: `vcs` and `command` are both in it.
        if rest in (["--help"], ["-h"], ["--version"]):
            return ""
        if len(rest) == 2 and rest[-1] == "--help" and rest[0] in UNITY_HELP_SUB:
            return ""                           # `unity <admitted-sub|test|build> --help`
        if (len(rest) == 3 and rest[-1] == "--help"
                and rest[1] in UNITY_SUB2_OK.get(rest[0], frozenset())):
            return ""                           # `unity <admitted-sub> <admitted-sub2> --help`
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
            # The testbed-scoped live-edit set is checked FIRST and separately, and its cwd
            # condition is evaluated before a single token of the tail is read.  [T4.0]
            if len(rest) >= 2 and rest[1] in UNITY_LIVE_EDIT:
                if not in_testbed():
                    return ("unity command " + rest[1] + ": the live-edit set is admitted only with"
                            " the hook's own cwd at the testbed")
                # The hook's cwd predicate stands in for the SHELL's cwd, and that substitution is
                # only sound when no other segment can have moved the shell -- `cd` is gone from the
                # set, but a future addition, or a `$PWD` the hook resolves against ITS cwd while
                # bash expands it after something else, would re-open it. So: last segment, nothing
                # but a prelude before it.  [round-6 review F6-1]
                if not SEG_CTX["nothing_after"]:
                    return ("unity command " + rest[1] + ": the live-edit set is admitted only as"
                            " the last segment of the command")
                if not SEG_CTX["prelude_before"]:
                    return ("unity command " + rest[1] + ": the live-edit set admits no segment"
                            " before it other than the unity env source or an export UNITY_*")
                has_pp = any(t == "--project-path" or t.startswith("--project-path=")
                             for t in rest[2:])
                if not has_pp and not SEG_CTX["nothing_before"]:
                    return ("unity command " + rest[1] + ": without --project-path the live-edit set"
                            " is admitted only as the WHOLE command")
                why = live_edit_tail_ok(rest[1], rest[2:])
                if why:
                    return why
                LIVE_EDIT[0] = True
                return ""
            if len(rest) < 2 or rest[1] not in UNITY_COMMAND_RO:
                return "unity command: editor command outside the read-only set"
            why = tail_ok(rest[2:], False)      # no --verbose here; the five names take no operands
            if why:
                return "unity command " + rest[1] + ": " + why
        elif s1 == "vcs":
            # `unity vcs` is read-only reporting only for `affected`; `unity vcs` bare and every other
            # `unity vcs <x>` fall through to normal permission evaluation, same as an unlisted
            # subcommand (T3.1).
            if len(rest) < 2 or rest[1] != "affected":
                return "unity vcs: only `affected` is read-only"
            why = vcs_affected_tail_ok(rest[2:])
            if why:
                return why
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
    segs = [s for s in segs if s]
    for i, seg in enumerate(segs):
        SEG_CTX["nothing_before"] = (i == 0)
        SEG_CTX["prelude_before"] = all(is_prelude(s) for s in segs[:i])
        SEG_CTX["nothing_after"] = (i == len(segs) - 1)
        why = check_segment(seg)
        if why:
            return why
    return ""

if len(cmd_raw) > SCAN_MAX:
    reason = "command longer than %d bytes" % SCAN_MAX
else:
    reason = evaluate(cmd_raw)
allow = (reason == "")
# Which set carried it, for the log and for the decision reason. `LIVE_EDIT[0]` is only meaningful
# when `allow` is true: a later segment can refuse a command whose earlier segment was live-edit.
SET_NAME = ("testbed live-edit set" if (allow and LIVE_EDIT[0]) else "read-only set")

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
            "reason": SET_NAME if allow else reason,
        }, separators=(",", ":")) + "\n")
except Exception:
    pass

if allow:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "permissionDecisionReason": ("unity-ops harness: testbed live-edit set"
                                     if LIVE_EDIT[0] else "unity-ops harness: read-only probe")}},
        separators=(",", ":")))
sys.exit(0)
PY
printf '%s' "$INPUT" | python3 -c "$UNITY_OPS_PERM_PY" 2>/dev/null || true
exit 0
