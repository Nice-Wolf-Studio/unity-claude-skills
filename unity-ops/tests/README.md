# unity-ops skill tests

These are **pressure scenarios**, not unit tests. There is no CI runner and none is planned for v1
(CI is an explicit non-goal — `../DESIGN.md` §6). They are run by a human or an orchestrating agent
as **headless `claude -p` sessions against a staged plugin root**.

## How a run is dispatched

    bash tests/stage.sh                      # BASELINE stage: hook only
    bash tests/stage.sh <skill> || exit 1    # RESULT stage:   hook + the skill under test
    bash tests/run_scenario.sh <tag> "<prompt>" transcripts/<tag>.json

`run_scenario.sh` is the ONLY dispatcher. It takes a `mkdir` lock, asserts the scenario flag is
absent, re-checks `claude auth status`, writes the tag, dispatches with an explicit
`--permission-mode dontAsk --allowedTools …` envelope **plus `--settings <harness-settings.json>`,
which registers the expansion-tolerant permission hook described in the next section** [T2.4b], and
captures the child's own `session_id`
to `transcripts/<tag>.session`. The dispatch runs in the **background** and the script blocks in
`wait` — bash defers a trap while blocked on a *foreground* child, so a foreground `claude -p`
made the trap useless for the whole life of the run. A `trap … EXIT INT TERM HUP` kills the child
and removes the flag and the lock even if the run is interrupted. Exit 2 = refused (another run in
flight, or a stale flag); exit 3 = `PRECONDITION_FAILED` (not logged in); **exit 4 =
`PRECONDITION_FAILED` (the transcript carried no `session_id`, so no `.session` file was written —
an empty one would poison every metric filter)**. **Never dispatch `claude -p` by hand** — an
untagged, unlocked, unrecorded run pollutes every metric and cannot be attributed afterwards.

`--verbose` is passed explicitly: without it `--output-format json` returns only the `result`
object, with no assistant messages and therefore no tool-use blocks. `< /dev/null` is required or
the CLI waits 3 s for stdin. Gate success on `is_error` / `terminal_reason`, never on `subtype`.
If `transcripts/shape-probe.json` shows no `assistant` envelopes, set `UNITY_OPS_FORMAT=stream-json`
and the parsers read NDJSON instead — both `trig()` and the session-id extractor accept either.

## The permission hook — why `--allowedTools` alone is not the envelope  [T2.4b] [#28]

Under `--permission-mode dontAsk` a `Bash(prefix*)` rule matches the **literal, pre-expansion**
command string. A command carrying a shell expansion has no statically-known effective command, so
the matcher declines rather than approve on the pre-expansion text. `unity list --project-path
"$PWD" …` therefore matches **no** rule — not `Bash(unity list*)`, not `Bash(unity *)`, and not even
a rule that literally spells `Bash(unity list --project-path "$PWD"*)`. T2.4 established that with
committed probes (`results/unity-surface-preflight.md`, issue #28). Because `unity-surface-preflight`
itself teaches `--arg p "$PWD"`, every rep would take that denial and be graded `INCONCLUSIVE`.

`run_scenario.sh` therefore writes
`${XDG_STATE_HOME:-$HOME/.local/state}/unity-ops/harness-settings.json` at dispatch time and passes
`--settings <that file>`. The settings register **one** `PreToolUse` hook on `Bash`:
`tests/permission-hook.sh`, which re-implements the **same** read-only set post-expansion-tolerantly
and returns `{"hookSpecificOutput":{…,"permissionDecision":"allow"}}` for it.

What it is and is not:

- **It never returns `deny`.** It can only *admit*; under `dontAsk` the default already denies, so a
  bug in the hook fails closed (denied), never open.
- **It changes the matching mechanism for `ALLOW`'s prefixes. Its set is not `ALLOW`'s set, and the
  delta runs in both directions** — `ALLOW` and `UNITY_OPS_ALLOW` themselves are untouched.
  - **Admitted expansion-tolerantly, from `ALLOW`:** the `unity`, `git`, `.`, `export` and `grep`
    prefixes — in several places **narrower** than `ALLOW` (below).
  - **Plus, not in `ALLOW`:** filters a probe runs over its **own** output, and only ones with no
    option that writes a file or executes a program — `cat head tail wc tr cut basename dirname
    realpath echo printf pwd ls date true test [ command which jq grep`, plus `cd`, which likewise
    cannot write or execute. `jq` additionally refuses `--rawfile`/`--slurpfile`/`-f`/`--from-file`
    (they read an arbitrary file; jq cannot write one — see the per-character short-option rule
    below), and `command` is allowed only as `command -v`
    (`command rm -rf x` **runs** `rm`). `git log` and `git show` are admitted too, which `ALLOW`
    carries for neither.
  - **Minus, still admitted by `ALLOW` literally:** `unity test` and `unity build`. Neither is
    read-only — a junit report, a build output — so the hook refuses both; `Bash(unity test*)` and
    `Bash(unity build*)` remain in the `ALLOW` array and a **literal** (expansion-free) spelling of
    either is still admitted by that route.
  - **Never in either:** `awk`, `sed`, `find`, `sort`, `uniq`. See the narrowing bullet.

  Adding to the set widens the envelope and needs the same scrutiny as adding a `Bash(...)` rule.
- **It is harness-only and is never staged.** `stage.sh` copies `.claude-plugin/`, `hooks/` and the
  named `skills/<name>/` directories and nothing else; no `tests/` file reaches
  `/tmp/unity-ops-stage`, so no plugin consumer ever gets this hook.  [G18] [G20]
- **Refused outright, whatever the rest of the command says:** command substitution (`$(…)`, backticks)
  anywhere in the string, any `>`/`>>`/`<` redirection other than to `/dev/null` or an `fd` dup
  (`2>&1`), heredocs, `(`/`)` grouping, and any segment whose command word is outside the set. Every
  segment of a `;`/`&&`/`||`/`|`/newline chain must pass; one bad segment refuses the whole command.
- **`awk`, `sed`, `find`, `sort` and `uniq` are not in the set at all.** Each writes a file or runs a
  program through a channel no tokenizer can see, because it lives inside a quoted program token or
  an option value: `awk 'BEGIN{system ("…")}'` (one space before the paren defeats any substring
  test, and it is full arbitrary execution), `sed -n 'w /path'` and `s/…/…/w /path`, `find -fprint0`
  (macOS `/usr/bin/find` lacks it, but Claude Code's shell snapshot shadows `find` with `bfs`, which
  implements it), `sort --compress-program=`, `uniq IN OUT`. A probe uses `grep`/`head`/`cut`/`jq`,
  or the `Grep` and `Glob` tools, instead.
- **Narrowed beyond the bare command word**, because these execute or write with no shell redirection
  for the segment scanner to see:
  - A segment beginning with a `NAME=value` assignment is **refused, not stripped**:
    `GIT_EXTERNAL_DIFF=/bin/sh git diff` runs a worktree file as a shell script, and `PATH=…` /
    `DYLD_INSERT_LIBRARIES=…` are the same shape. The harness exports every `UNITY_*` variable a
    probe needs before the dispatch, so nothing legitimate needs a leading assignment.
  - `export` is allowed only when **every** argument matches `UNITY_[A-Z0-9_]+=<literal>` (no `$`,
    no backtick). `export PATH=…`, `export GIT_EXTERNAL_DIFF=…` and bare `export NAME` are refused.
  - `.`/`source` takes exactly one argument and it must be **exactly** `"$HOME/.unity/env"`,
    `$HOME/.unity/env`, `~/.unity/env` or `/Users/<you>/.unity/env` (the expanded form). Any other
    path ending `/.unity/env` is refused: sourcing runs the file as shell, and the child holds the
    unrestricted `Write` tool, so `Write /tmp/x/.unity/env` + `. /tmp/x/.unity/env` would have been
    arbitrary execution (round-2 review R2-1).
  - **A command word containing `/` is refused outright.** Matching on the basename admitted
    `/tmp/evil/git status` and `./git status` — whatever sits at that path is not the binary this set
    was reasoned about (R2-2).
  - `git` must be `git [-C <path>] <status|diff|rev-parse|log|show> [args]`, and the whole segment is
    refused if **any** token starts with `-c`, `--config-env`, `--exec-path`, `--git-dir`,
    `--work-tree`, `--output`, `--ext-diff`, `--textconv`, `-O`, `-o` or `--orderfile`
    (`git -c diff.external=/bin/sh diff` executes; `git diff --output=<path>` writes). `--no-index`
    is fine.
  - `unity skill install --list` is an **exact token match**, optionally followed only by `--format`,
    `json`, `--no-pager`; `unity skill install <target> --list` is refused. `unity pipeline` is
    `list` only; `unity command` is the five read-only editor commands; every
    `--yes`/`--force`/`--allow-install`/`--confirm` spelling is refused outright.
  - **`unity vcs` is `affected` only** (T3.1) — `unity vcs` bare and every other `unity vcs
    <x>` fall through to normal permission evaluation, same as any unlisted subcommand. `unity vcs
    affected [path] [options]` is read-only reporting (it diffs against the merge base with `--since`,
    never writes). Admitted trailing tokens, in any combination: one optional positional path (refused
    if it starts with `-`; a `$(`/backtick anywhere in the whole command is already refused above this
    check), `--since <ref>` (the value must not itself start with `-`), `--format json`, `--json`,
    `--no-pager`, `--no-banner`, `--non-interactive`, `--quiet`, `--timeout <digits>`, `--verbose` —
    or `--help`/`-h`, but **only** as the sole trailing token, mixed with nothing else. Everything else
    the CLI accepts here is refused, most importantly the two options that are not read-only:
    `--proxy <url>` sends the run's traffic through an arbitrary proxy, and `--log-proxy` writes
    `proxy-request.json` into the project — neither belongs in a read-only set, so neither is admitted
    (`--proxy-disable`, `--no-log-proxy` and `-V` are refused too, simply because they are not on the
    admit list). Live probe: `permission-hook-probe-vcs-affected.json`, `permission_denials: []`,
    exit 0. `run_scenario.sh`'s `ALLOW` array is unchanged by this addition — `unity vcs affected` is
    admitted only through this hook, exactly like the `"$PWD"`-expansion case the hook was built for.
  - **`--help`/`-h` must be the last token and nothing may follow it** — the accepted forms are
    exactly `unity --help`, `unity -h`, `unity --version`, `unity <sub> --help` and
    `unity <sub> <sub2> --help`. `unity skill --help install /x` and `unity --help close` are refused
    (R2-4), and `ALLOW`'s `Bash(unity * --help)` has no trailing `*` either.
  - **Everything after the subcommand is an option whitelist** (R2-5): `--project-path <value>`,
    `--format json` (no other value), `--no-pager`, `--timeout <digits>`, and `--verbose` for
    `unity status` / `unity list` / `unity pipeline list` but not after a `unity command` editor
    command. `unity command editor_status extra` and `unity status --format yaml` are refused.
  - `jq` short options are checked **per character**, so a cluster cannot smuggle a file read:
    `jq -nf /tmp/x` and `jq -L /tmp 'include …'` are refused alongside `-f`, `--from-file`,
    `--rawfile`, `--slurpfile`, `--library-path` and `--run-tests` (R2-3).
- **Limits — all of them over-refusals, which is the safe direction.** `#` is not treated as a
  comment (a comment could otherwise hide a second line from the hook that bash still runs), so a
  genuine inline comment refuses the command. A *quoted literal* `>` or `<` argument (`grep '>' f`)
  is indistinguishable from a redirection after quote removal and refuses the command. A command
  over 64 KB is refused unread. In every case the fallback is the pre-existing `--allowedTools`
  evaluation, i.e. a `dontAsk` denial — the hook cannot make anything **more** permissive than the
  set above.

Log: one JSONL line per Bash call in
`${XDG_STATE_HOME:-$HOME/.local/state}/unity-ops/permission-hook.jsonl` —
`{"ts","session_id","scenario","command","decision":"allow"|"pass","reason"}`. `scenario` comes from
the same `scenario.current` flag file the guard reads, so a scenario's admissions are attributable;
a probe run outside `run_scenario.sh` logs an empty `scenario`.

### Acceptance probes (T2.4b, 2026-09-14, CLI 2.1.270, `--model sonnet`)

**Re-captured against the fixed hook** after the round-1 review; the superseded transcripts were
replaced rather than kept, so the committed evidence corresponds to the committed code. Rows **1, 2
and 6 were re-captured a second time** after the round-2 narrowing (R2-1…R2-5): a narrowing can only
break the positive path, so only the three rows that must stay at 0 were re-run — 3, 4, 5, 5b and m1
are unchanged from the round-1 re-capture and their transcripts are untouched.

Each is a one-shot `claude -p` from `~/Dev/Unity/ai_test` after `. "$HOME/.unity/env"` — **not** a
scenario: no `--plugin-dir`, no `run_scenario.sh`, so none wrote a guard record. Envelope: the
default `ALLOW` array exactly as `run_scenario.sh` spells it, `--permission-mode dontAsk`,
`--settings ~/.local/state/unity-ops/harness-settings.json` (regenerated by `run_scenario.sh`'s own
code path, via `UNITY_OPS_DRYRUN=1`), `--output-format json --verbose`, `< /dev/null`. Transcripts
are under `transcripts/`. The literal invocation, with `${ALLOW[@]}` the array above:

    claude -p --output-format json --verbose --model sonnet \
      --permission-mode dontAsk --allowedTools "${ALLOW[@]}" \
      --settings "$HOME/.local/state/unity-ops/harness-settings.json" \
      -- "Run exactly this command, once, and report its exit code and the first line of its
          output. Do not modify the command, do not substitute a different one, and do not retry
          with a workaround if it is blocked:

          <COMMAND>" < /dev/null

Row m1 is the one exception: `--allowedTools "Bash(unity list*)"` and **no** `--settings`.

| # | Command sent | Expected | Observed `permission_denials` | session_id | Transcript |
|---|---|---|---|---|---|
| 1 | `unity list --project-path "$PWD" --format json --no-pager` | 0, **and it runs** | **0** — ran; exit 6 `COMMAND_FAILED` ("No Pipeline instance found"), the expected *command* result with the Editor closed | `2b11d0a5-797b-47eb-b568-ed91068ece21` | `permission-hook-probe-1.json` |
| 2 | `unity pipeline list --format json --no-pager \| jq '.data.summary'` | 0 | **0** — ran; exit 0, the six summary counters returned | `1cc85a55-424c-47b0-ba95-5c66d7f0e78c` | `permission-hook-probe-2.json` |
| 3 | `unity close` | ≥ 1, **never runs** | **1** — denied; the only `tool_result` is the don't-ask denial text (`is_error: true`), and `unity status` was still `STATUS_NO_INSTANCES` after the set | `6511005e-59c5-4949-b1ef-4331040ab974` | `permission-hook-probe-3.json` |
| 4 | `unity list --project-path "$PWD" --format json > /tmp/unity-ops-probe-leak.txt` | ≥ 1 | **1** — denied on the redirection (the model appended `; echo "EXIT:$?"`, which the hook logged and refused just the same); `test ! -e /tmp/unity-ops-probe-leak.txt` passes | `de8d2211-a08e-4e7c-98eb-c0447ca616b5` | `permission-hook-probe-4.json` |
| 5 | `echo "$(rm -rf /tmp/unity-ops-probe-never)"` | ≥ 1 | **0 — the *model* refused before issuing any Bash call**, so nothing reached the permission layer; the hook log has no line for this session. Not a hook failure and not a hook test either: see 5b. The path does not exist | `35bc44dc-fb7f-4e95-a61d-94b53e49152b` | `permission-hook-probe-5.json` |
| 5b | `echo "$(pwd)"` | ≥ 1 | **1** — the same `$(` rejection with a *benign* payload, so the refusal is attributable to the hook and not to the model declining a destructive command. **This row, not row 5, is the control** | `cd78930b-01a0-46a8-ab4c-a7f25b1459e7` | `permission-hook-probe-5b.json` |
| 6 | `git -C "$PWD" status --porcelain` | 0 | **0** — ran; exit 0 | `c12161fc-da3d-4786-b905-0e8b253d6c08` | `permission-hook-probe-6.json` |
| m1 | `unity list --project-path /Users/jeremymiranda/Dev/Unity/ai_test --format json --no-pager`, under the default rule `Bash(unity list*)` **only**, no `--settings` | 0 | **0** — ran; exit 6 `COMMAND_FAILED`. The literal-path control for F1: same command, same rule, only `"$PWD"` differs | `136f7632-9787-4de6-99e2-ce2127cb7a57` | `permission-probe-literal-allowed.json` |

Probe 5 is why 5b exists, and it has now scored **0 on one pass and 1 on another with the command
unchanged** — purely because the model sometimes declines a destructive command before calling the
tool. A "≥ 1 denial" criterion is satisfiable by model mood; the criterion that actually holds is
what did **not** happen (`/tmp/unity-ops-probe-never` does not exist, `/tmp/unity-ops-probe-leak.txt`
does not exist, the Editor is still closed), with the denial count as corroboration. 5b carries a
benign payload precisely so nothing but the hook can explain its refusal.

After the set: `bash /tmp/unity-ops-check-testbed.sh` → `GATE: PASS` (all seven counters 0);
`unity status --format json` → `STATUS_NO_INSTANCES` (exit 6); `decisions.jsonl` unchanged at 40
lines (no `--plugin-dir`, so the plugin's guard never loaded); `permission-hook.jsonl` gained
**exactly 6 lines** for the full set — one per Bash call that actually reached the permission layer —
**3 `allow`, 3 `pass`**, each carrying the reason; the round-2 re-run of rows 1, 2 and 6 appended
**3 more, all `allow`**, for 9 in total. There is no line for probe 5 (the model issued no Bash call)
and none for m1 (dispatched without `--settings`, so without the hook). `bash -n` clean on
`permission-hook.sh`, `permission-hook-test.sh` and `run_scenario.sh`;
`bash tests/stage.sh unity-surface-preflight` lists no `tests/` file.

### `permission-hook-test.sh` — the regression gate

    bash unity-ops/tests/permission-hook-test.sh     # exit 0 = every row matched

`tests/permission-hook-test.sh` is a committed table of `expected<TAB>command` rows (`allow` |
`pass`) fed straight to the hook as `PreToolUse` payloads. It carries **every bypass payload from the
T2.4b round-1 review** — `awk 'BEGIN{system ("…")}'`, `GIT_EXTERNAL_DIFF=/bin/rm git diff`,
`sed -n 'w /tmp/x'`, `find . -fprint0 /tmp/o`, `git diff --output=…`, `git -c diff.external=/bin/sh
diff`, `export PATH=/tmp`, `PATH=/tmp/x ls`, `unity skill install /tmp/x --list`,
`sort --compress-program=`, `uniq IN OUT`, `unity test`, `unity build`, `. /etc/profile`,
`jq -f /tmp/x .` — and every round-2 payload — `. /tmp/evil/.unity/env`,
`source <testbed>/.unity/env`, `. /etc/../tmp/evil/.unity/env`, `/tmp/evil/git status`,
`./git status`, `jq -nf /tmp/x`, `jq -L /tmp 'include …'`, `jq --run-tests`,
`unity skill --help install /x`, `unity --help close`, `unity command editor_status extra`,
`unity status --format yaml`, the glued `git -cdiff.external=…`, `$'\x72\x6d' -rf`,
`{rm,-rf,/tmp/z}`, `cat <<< "x"`, `echo x >& /tmp/o` — all expected `pass`, alongside the read-only
set expected `allow` (`unity -h`, `unity command editor_status … --timeout 5000`, … ). It redirects
`XDG_STATE_HOME` into a throwaway directory, so it writes **no** line to the committed
`permission-hook.jsonl`, and it exits non-zero printing every mismatching row. **Increment 9's CI
should run it**; until then it is run by hand before any change to the hook. A row that flips is a
change to the permission envelope and must be argued for, not absorbed.

The seven probe transcripts above are the end-to-end evidence (the hook inside a real `claude -p`
child); this table is the unit-level evidence (the hook as a pure stdin→stdout filter).

## Before any LIVE run — the precondition

    cd ~/Dev/Unity/ai_test && pwd
    cat ProjectSettings/ProjectVersion.txt
    . "$HOME/.unity/env"
    export UNITY_NO_BANNER=1 UNITY_NON_INTERACTIVE=1 UNITY_NO_PAGER=1 UNITY_NO_CONSENT_PROMPT=1 UNITY_NO_UPDATE_CHECK=1
    unity status --format json
    test -f /tmp/unity-ops-testbed-snapshot.json && echo "snapshot: present" || echo "snapshot: MISSING"
    claude auth status || true      # exits 1 when logged out; tolerated, never a block-killer

The project must read `6000.3.10f1`, `data.instances[]` must contain this project at state `ready`,
the snapshot must be present, and `claude auth status` must report a logged-in session. A scenario
requiring a **persistent-headless** Editor instead asserts `unity list --project-path ~/Dev/Unity/ai_test`
answering — a batch-launched Editor serves commands and is **not listed by `unity status`** at all.

If any assertion fails the scenario is **not run**. Record verdict `PRECONDITION_FAILED`, name the
assertion, quote its output, and halt the increment. A LIVE scenario dispatched with no Editor does
not fail — it succeeds at a different test and produces a transcript that looks like evidence and is not.

## Tag every run — and attribute it by session id

`run_scenario.sh` writes `${XDG_STATE_HOME:-$HOME/.local/state}/unity-ops/scenario.current` before
the dispatch and removes it from a `trap` after; the hook reads it into each record's `scenario`
field. Hooks fire inside subagents, so an untagged run would otherwise pollute every metric in
`metrics.md`.

**The tag is the convenience; `session_id` is the record of truth.** Each dispatch writes the
child's session id to `transcripts/<tag>.session`, and every query in `metrics.md` excludes the
union of those ids. A tag can be lost (a crash between `printf` and the dispatch); a session id
cannot, because it comes out of the transcript the run itself produced.

There is no `UNITY_OPS_SCENARIO` variable. The Agent tool takes no environment parameter, an
`export` does not survive to the next Bash call, and the hook process is spawned by the harness —
so the variable could never have reached the hook.

## Briefs live here, never inside a transcript

`briefs/<skill>.md` holds the text given to the session. It is **never** pasted into
`baselines/<skill>.md` or `results/<skill>.md`, because those files are what the gates grep — a gate
that greps a file containing its own search term cannot fail.

## How to run one

1. Read `scenarios/<skill>.md`. It declares a mode (LIVE or SIMULATED), the pressures, the prompt,
   and — in a section **you read and the session never sees** — the rationalization it predicts.
2. Stage, then dispatch with `run_scenario`, in the background. Baseline: stage **without** the skill.
   Force-fed: stage **with** it, prompt prefixed `read unity-ops:<skill> first. `. Natural: stage
   **with** it, prompt bare.
3. Every brief ends with: "Findings, defects and follow-ups are reported back to me for a GitHub
   issue. Never create a task chip."
4. Keep the raw transcript at `transcripts/<tag>.json` and its `.session` file beside it. Assert the plugin loaded:
   `jq -r '(if type=="array" then .[] else . end) | select(.type=="system" and .subtype=="init") | .plugins[]?.name' <t>`
   must print `unity-ops`.
5. Write the human record to `baselines/<skill>.md` (three reps) or `results/<skill>.md` (two runs)
   using the recording template at the bottom of the scenario file, and **fill the `VERDICT_RED:` and
   `TRIGGERED:` lines**. An unfilled template can only fail.
6. Run `bash /tmp/unity-ops-check-testbed.sh`. Revert only paths the gate reports as ADDED. **Never**
   `git checkout --` a path that is in the snapshot — that is Jeremy's work.
7. Commit the transcript. The committed transcript **is** the evidence; a claim that a skill works
   without one is unsupported (`wolf-core:wolf-verification`).

## Verdicts

| Verdict | Meaning |
|---|---|
| `RED` | `grep -c '^VERDICT_RED: YES$'` ≥ 2 across the three baseline reps. Write the skill. |
| `CUT` | 0 of 3. **A valid TDD outcome.** The installed dependency already suffices; the skill is not
written. File a GitHub issue with the three transcripts and move to the next increment. Exception:
`unity-cli-contract` is never cut outright — it carries the dependency stop. |
| `INCONCLUSIVE` | 1 of 3. Run reps 4 and 5; still <50% → treat as `CUT`. |
| `GREEN` | The force-fed run performed the gated behaviour **and** the natural run's transcript
contains a `Skill` tool use naming `unity-ops:<skill>`. |
| `TRIGGER-FAIL` | Content works force-fed, but the natural run scored `0` on BOTH the hook
join (`trig_hook`) and `trig()`. A finding, not a pass. |
| `INCONCLUSIVE` | …or `PERMISSION_DENIALS` > 0 on a `unity` probe: the envelope, not the model,
produced the behaviour. Re-run with the entry added to `--allowedTools`. |
| `PRECONDITION_FAILED` | A LIVE precondition assertion failed. The scenario did not run. |
| `UNEXPECTED` | Anything else. Record it and decide explicitly. |

## Modes

| Mode | Meaning |
|---|---|
| LIVE | The session has Bash and acts against `~/Dev/Unity/ai_test` for real. |
| SIMULATED | The prompt *states* the environment and asks what the session will run, without running
it. Used where a real run would discard work or take an hour. |

## Directory contract

- `scenarios/` — the input. Stable; edited only when the design changes.
- `briefs/` — the text handed to the session. Never duplicated into a graded file.
- `transcripts/` — raw `claude -p --output-format json --verbose` output, one file per run.
- `baselines/` — RED evidence, captured before the skill existed. **Never** re-run or overwrite a
  baseline after its skill ships; it is the historical record of the failure.
- `results/` — GREEN evidence, captured after. Re-run and overwrite when a skill is revised.
- `metrics.md` — how each DX metric is computed from the hook's JSONL log.
- `stage.sh`, `run_scenario.sh`, `restatement-audit.sh` — the three scripts every increment calls.
- `permission-hook.sh` — the harness-only `PreToolUse` permission hook `run_scenario.sh` passes via
  `--settings`. **Never staged into the plugin.**  [T2.4b]
- `transcripts/<tag>.session` — the child session's own id. The primary metric filter.
- `transcripts/shape-probe.json` — the observed envelope shape every parser is asserted against.
- `testbed-snapshot.md`, `pipeline-list-shape.md` — increment-0 observations every later task depends on.
