#!/bin/bash
# unity-ops/tests/permission-hook-test.sh — regression gate for tests/permission-hook.sh.  [T2.4b-r1]
#
# WHY. The hook is the ONLY gate on `Bash` in a scenario child: the plugin's own `unity-ops-guard` is
# v1 SHADOW mode and never denies, and the child holds unrestricted `Write`/`Edit`. Round 1 of the
# T2.4b review found five entries of the "read-only set" that were not read-only — two of them
# arbitrary code execution. Every payload from that review is a row below, expected `pass`.
#
# USAGE:  bash unity-ops/tests/permission-hook-test.sh
# Exit 0 = every row matched. Exit 1 = at least one mismatch (each is printed). Exit 2 = setup fault.
#
# The table is `expected<TAB>command`, `expected` ∈ {allow, pass}. `pass` means the hook prints
# NOTHING, which under `--permission-mode dontAsk` is a denial. The three characters `<NL>` in a
# command mean a literal newline (a second command hidden on a second line). `#` starts a table
# comment only at the START of a line; blank lines are skipped.
#
# The log override is XDG_STATE_HOME (the hook already resolves its state directory from it): it is
# redirected into a throwaway directory for the whole run, so this test writes NO line to
# ~/.local/state/unity-ops/permission-hook.jsonl and cannot contaminate the committed evidence.
set -u
HERE="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
HOOK="$HERE/permission-hook.sh"
[ -f "$HOOK" ] || { echo "permission-hook-test: $HOOK is missing" >&2; exit 2; }
python3 -c 'pass' >/dev/null 2>&1 || { echo "permission-hook-test: no working python3" >&2; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/unity-ops-hooktest.XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT
export XDG_STATE_HOME="$TMP/state"

cat > "$TMP/table.tsv" <<'TABLE_EOF'
# ---- ROUND-1 REVIEW BYPASSES: every one of these MUST be `pass` ----
# C1 — awk system() with whitespace before the paren = arbitrary execution
pass	awk 'BEGIN{system ("touch /tmp/unity-ops-pwned")}'
pass	awk 'BEGIN{system("rm -rf /tmp/unity-ops-z")}'
pass	awk 'BEGIN{cmd="rm -rf /tmp/unity-ops-z"; system (cmd)}'
pass	awk '{print}' file
# C2 — leading NAME=value assignment + an admitted command = arbitrary execution
pass	GIT_EXTERNAL_DIFF=/bin/rm git diff
pass	GIT_EXTERNAL_DIFF=/tmp/evil.sh git diff HEAD
pass	GIT_EXTERNAL_DIFF=id git log -p --ext-diff
pass	GIT_PAGER=/tmp/evil.sh git log
pass	FOO=1 unity status
# H1 — sed -n still writes files through `w` and `s///w`
pass	sed -n 'w /tmp/unity-ops-pwned' file
pass	sed -n '1w /tmp/unity-ops-pwned' file
pass	sed -n 's/alpha/X/w /tmp/unity-ops-pwned' file
pass	sed -n 1p file
pass	sed -i '' s/a/b/ file
# H2 — find -fprint0 writes (Claude Code's shell shadows find with bfs, which implements it)
pass	find . -fprint0 /tmp/unity-ops-out
pass	find . -name ProjectVersion.txt
pass	find . -delete
# H3 — git writes a file / runs a program with no shell redirection
pass	git diff --output=/tmp/unity-ops-pwned
pass	git diff --output /tmp/unity-ops-pwned
pass	git show --output=/tmp/unity-ops-pwned
pass	git log -p --output=/tmp/unity-ops-pwned
pass	git -c diff.external=/bin/sh diff
pass	git --exec-path=/tmp status
pass	git --git-dir=/tmp/x status
pass	git --work-tree=/tmp/x status
pass	git diff -O/tmp/orderfile
pass	git -C "$PWD" diff --textconv
# M-PATH / M-DYLD — same assignment root cause
pass	PATH=/tmp/x ls
pass	DYLD_INSERT_LIBRARIES=/tmp/evil.dylib ls
pass	export PATH=/tmp
pass	export GIT_EXTERNAL_DIFF=/bin/sh
pass	export UNITY_X=$HOME
pass	export UNITY_NO_BANNER
# M2 — `unity skill install <target> --list` is NOT the ALLOW literal
pass	unity skill install /tmp/x --list
pass	unity skill install ./mypkg --list --force
pass	unity skill install --list /tmp/x
# M-sort — sort/uniq write files with no redirection
pass	sort --compress-program=/bin/sh f
pass	sort -o out f
pass	uniq a b
# M4 — unity test / unity build are not read-only
pass	unity test
pass	unity build
# source / jq
pass	. /etc/profile
pass	source ~/.zshrc
pass	jq -f /tmp/x .
pass	jq --rawfile a /etc/passwd .
pass	jq --slurpfile a /etc/passwd .
# ---- refusals the round-1 review confirmed: these MUST stay `pass` ----
pass	unity close
pass	unity command save_all
pass	unity pipeline install
pass	git -C "$PWD" checkout -- .
pass	cat x > y
pass	unity list --project-path "$PWD" --format json > /tmp/unity-ops-probe-leak.txt
pass	echo "$(rm -rf /tmp/unity-ops-probe-never)"
pass	echo "$(pwd)"
pass	env FOO=1 unity close
pass	sh -c 'rm -rf /tmp/unity-ops-z'
pass	eval "rm -rf /tmp/unity-ops-z"
pass	exec rm -rf /tmp/unity-ops-z
pass	time rm -rf /tmp/unity-ops-z
pass	xargs rm < list
pass	cat <<EOF
pass	cat <(ls)
pass	(unity status)
pass	/bin/rm -rf /tmp/unity-ops-z
pass	command rm -rf /tmp/unity-ops-z
pass	unity status; unity close
pass	unity status && rm -rf /tmp/unity-ops-z
pass	ls<NL>rm -rf /tmp/unity-ops-z
pass	ls # note<NL>rm -rf /tmp/unity-ops-z
pass	python3 -c 'import os'
# ---- ROUND-2 REVIEW (R2-1..R2-5) ----
# R2-1 — `.`/`source` took ANY absolute path ending /.unity/env; the child can Write that file first
pass	. /tmp/evil/.unity/env
pass	. "/tmp/evil/.unity/env"
pass	. /tmp/x/y/z/.unity/env
pass	source /Users/jeremymiranda/Dev/Unity/ai_test/.unity/env
pass	. /etc/../tmp/evil/.unity/env
pass	. ./.unity/env
# R2-2 — a path-qualified command word was admitted on its basename
pass	/tmp/evil/git status
pass	./git status
pass	../../usr/bin/git status
pass	/tmp/evil/unity close
# R2-3 — the jq file-read denylist was bypassable by spelling
pass	jq -nf /tmp/x
pass	jq -L /tmp 'include "x"; .'
pass	jq -L/tmp '.'
pass	jq --run-tests /tmp/x
pass	jq --library-path /tmp '.'
# R2-4 — `--help` short-circuited ahead of the subcommand check
pass	unity skill --help install /x
pass	unity --help close
pass	unity close -h
# R2-5 — unlimited trailing arguments after a read-only editor command / subcommand
pass	unity command editor_status extra
pass	unity command editor_status --json {"a":1}
pass	unity status --format yaml
pass	unity list --project-path
pass	unity command editor_status --timeout abc
# glued spelling of the git -c bypass
pass	git -cdiff.external=/bin/sh diff
# quoting / expansion tricks the round-2 reviewer attacked (must stay pass)
pass	$'\x72\x6d' -rf /tmp/unity-ops-z
pass	{rm,-rf,/tmp/unity-ops-z}
pass	cat <<< "x"
pass	echo x >& /tmp/unity-ops-o
pass	git -C /tmp -C /etc status
pass	git -C
# ---- the read-only set: these MUST be `allow` ----
allow	unity -h
allow	unity --help
allow	unity skill --help
allow	unity command editor_status --project-path "$PWD" --format json --no-pager --timeout 5000
allow	unity list --project-path "$PWD" --format json --no-pager --verbose

allow	unity list --project-path "$PWD" --format json --no-pager 2>&1
allow	unity pipeline list --format json --no-pager | jq '.data.summary'
allow	git -C "$PWD" status --porcelain
allow	. "$HOME/.unity/env"
allow	. $HOME/.unity/env
allow	. ~/.unity/env
allow	. /Users/jeremymiranda/.unity/env
allow	export UNITY_NO_BANNER=1
allow	export UNITY_NO_BANNER=1 UNITY_NON_INTERACTIVE=1 UNITY_NO_PAGER=1
allow	command -v unity
allow	unity command editor_status --project-path "$PWD" --format json
allow	grep -c foo file
allow	cat file | head -5
allow	pwd && ls ProjectSettings/ProjectVersion.txt
allow	unity skill install --list
allow	unity skill install --list --format json --no-pager
allow	unity status --format json --no-pager
allow	unity --version
allow	unity close --help
allow	unity list --project-path "$PWD" --format json 2>/dev/null
allow	git rev-parse --show-toplevel
allow	git log --oneline -5
allow	git -C "$PWD" diff --no-index a b
allow	cat ProjectSettings/ProjectVersion.txt 2>/dev/null
allow	jq '.data.summary' file.json
allow	cd /tmp && unity status
allow	test -f ProjectSettings/ProjectVersion.txt
allow	which unity
allow	wc -l file
allow	cut -d: -f1 file
allow	tr -d x
allow	realpath .
allow	basename /a/b
allow	echo hello
allow	unity pipeline list --format json --no-pager
allow	ls >/dev/null
# ---- T3.1 — unity vcs affected (option whitelist) ----
allow	unity vcs affected
allow	unity vcs affected --format json --no-pager
allow	unity vcs affected --since HEAD~1 --format json
allow	unity vcs affected "$PWD" --json
allow	unity vcs affected --help
pass	unity vcs affected --log-proxy
pass	unity vcs affected --proxy http://x:1 --json
pass	unity vcs affected --since "$(id)"
pass	unity vcs affected --since -x
pass	unity vcs status
pass	unity vcs affected extra1 extra2
pass	unity vcs affected --format tsv
TABLE_EOF

python3 - "$HOOK" "$TMP/table.tsv" <<'PY'
import json, subprocess, sys

hook, table = sys.argv[1], sys.argv[2]
rows, bad = [], []
for n, line in enumerate(open(table, encoding="utf-8"), 1):
    line = line.rstrip("\n")
    if not line.strip() or line.startswith("#"):
        continue
    if "\t" not in line:
        print("permission-hook-test: table line %d has no TAB: %r" % (n, line), file=sys.stderr)
        sys.exit(2)
    exp, cmd = line.split("\t", 1)
    exp = exp.strip()
    if exp not in ("allow", "pass"):
        print("permission-hook-test: table line %d: expected must be allow|pass, got %r" % (n, exp),
              file=sys.stderr)
        sys.exit(2)
    rows.append((n, exp, cmd.replace("<NL>", "\n")))

failed = []
for n, exp, cmd in rows:
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": cmd},
                          "session_id": "hook-test"})
    r = subprocess.run(["bash", hook], input=payload, capture_output=True, text=True)
    out = r.stdout.strip()
    got = "pass"
    if out:
        try:
            d = json.loads(out)
            if d["hookSpecificOutput"]["permissionDecision"] == "allow":
                got = "allow"
            else:                       # the hook must NEVER emit anything but allow
                got = "OTHER:" + json.dumps(d)
        except Exception:
            got = "UNPARSEABLE:" + out
    if r.returncode != 0:
        got = "RC%d:%s" % (r.returncode, got)
    if got != exp:
        failed.append((n, exp, got, cmd))

if failed:
    print("MISMATCHES (line / expected / got / command):")
    for n, exp, got, cmd in failed:
        print("  line %-4d expected=%-5s got=%-5s  %s" % (n, exp, got, cmd.replace("\n", "<NL>")))
print("permission-hook-test: %d passed, %d failed (of %d rows)"
      % (len(rows) - len(failed), len(failed), len(rows)))
sys.exit(1 if failed else 0)
PY
exit $?
