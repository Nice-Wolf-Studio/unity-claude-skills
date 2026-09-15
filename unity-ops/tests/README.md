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
- **It changes the matching mechanism, not the admitted set.** `ALLOW` and `UNITY_OPS_ALLOW` are
  untouched. Every entry in the hook's set has a counterpart in `ALLOW`, plus the pure text filters
  (`jq`, `grep`, `head`, `wc`, `sed -n`, …) a probe uses on its **own** output. Adding to the set
  widens the envelope and needs the same scrutiny as adding a `Bash(...)` rule.
- **It is harness-only and is never staged.** `stage.sh` copies `.claude-plugin/`, `hooks/` and the
  named `skills/<name>/` directories and nothing else; no `tests/` file reaches
  `/tmp/unity-ops-stage`, so no plugin consumer ever gets this hook.  [G18] [G20]
- **Refused outright, whatever the rest of the command says:** command substitution (`$(…)`, backticks)
  anywhere in the string, any `>`/`>>`/`<` redirection other than to `/dev/null` or an `fd` dup
  (`2>&1`), heredocs, `(`/`)` grouping, and any segment whose command word is outside the set. Every
  segment of a `;`/`&&`/`||`/`|`/newline chain must pass; one bad segment refuses the whole command.
- **Limits.** `#` is not treated as a comment (a comment could otherwise hide a second line from the
  hook that bash still runs), so a genuine inline comment refuses the command. `sed` needs `-n` and
  refuses `-i`; `awk` refuses any program text containing `>`, `|` or `system(`; `find` refuses
  `-delete`/`-exec`-family primaries. A command over 64 KB is refused unread.

Log: one JSONL line per Bash call in
`${XDG_STATE_HOME:-$HOME/.local/state}/unity-ops/permission-hook.jsonl` —
`{"ts","session_id","scenario","command","decision":"allow"|"pass","reason"}`. `scenario` comes from
the same `scenario.current` flag file the guard reads, so a scenario's admissions are attributable;
a probe run outside `run_scenario.sh` logs an empty `scenario`.

### Acceptance probes (T2.4b, 2026-09-14, CLI 2.1.270, `--model sonnet`)

Each is a one-shot `claude -p` from `~/Dev/Unity/ai_test` after `. "$HOME/.unity/env"` — **not** a
scenario: no `--plugin-dir`, no `run_scenario.sh`, so none wrote a guard record.

| # | Command sent | Envelope | Expected | Observed `permission_denials` | Transcript |
|---|---|---|---|---|---|
| 1 | `unity list --project-path "$PWD" --format json --no-pager` | default `ALLOW` + `--settings` | 0, and it runs | **0** (ran; exit 6 `COMMAND_FAILED`, Editor closed) | `transcripts/permission-hook-probe-1.json` |
| 2 | `unity pipeline list --format json --no-pager \| jq '.data.summary'` | default `ALLOW` + `--settings` | 0 | **0** (ran; exit 0) | `transcripts/permission-hook-probe-2.json` |
| 3 | `unity close` | default `ALLOW` + `--settings` | ≥ 1, never runs | **1**, no `tool_result` running it | `transcripts/permission-hook-probe-3.json` |
| 4 | `unity list --project-path "$PWD" --format json > /tmp/unity-ops-probe-leak.txt` | default `ALLOW` + `--settings` | ≥ 1 | **1**; `test ! -e /tmp/unity-ops-probe-leak.txt` passes | `transcripts/permission-hook-probe-4.json` |
| 5 | `echo "$(rm -rf /tmp/unity-ops-probe-never)"` | default `ALLOW` + `--settings` | ≥ 1 | **0** — the model refused *before* issuing any Bash call, so nothing reached the permission layer. The command did not run and the path does not exist. See 5b. | `transcripts/permission-hook-probe-5.json` |
| 5b | `echo "$(pwd)"` | default `ALLOW` + `--settings` | ≥ 1 | **1** — the same `$(` rejection path, exercised through the real permission stack with a command the model will actually issue | `transcripts/permission-hook-probe-5b.json` |
| 6 | `git -C "$PWD" status --porcelain` | default `ALLOW` + `--settings` | 0 | **0** (ran; exit 0, 45 lines) | `transcripts/permission-hook-probe-6.json` |

After the set: `bash /tmp/unity-ops-check-testbed.sh` → `GATE: PASS`; `unity status --format json`
→ `STATUS_NO_INSTANCES` (exit 6); `decisions.jsonl` unchanged at 40 lines;
`permission-hook.jsonl` gained exactly 7 lines — one per Bash call the probes issued (probe 5 issued
none), four `allow` and three `pass`.

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
