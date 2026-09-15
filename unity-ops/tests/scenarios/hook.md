# Hook scenario — unity-ops-guard

**Mode:** LIVE

The only test `hooks/unity-ops-guard` will ever get. The marketplace's `evals/hook-injection.test.sh`
does not cover it — that suite asserts four hardcoded paths under `wolf-core/` and `productivity/`
and never iterates plugins, which is why `banker`'s existing `PreToolUse` hook passes CI untested.

There is no baseline run: the hook has no "without it" behaviour to capture.

## What Part A proves

Part A pipes synthetic stdin straight into the guard — cheap, deterministic, needs no session at
all, and runs whether or not the CLI is logged in. It proves the **matching logic**:

- the six plan cases (a)–(f), the twenty-three round-3 Critic attacks, and the eleven regression
  extras all classify to the recorded pattern/subcommand/project, or record nothing when they must
  record nothing (heredoc bodies, quoted prose, `npm install --force`, a `.cs` write outside any project);
- the bash pre-filter reads only `command` / `file_path` / `skill` — never `cwd`, never `content` —
  and spawns **no** `python3` on a non-Unity payload, asserted by a counting wrapper rather than inferred from a timing;
- a 1 MB command stays inside the latency budget, truncates what is *stored* and *classified* but not what is *detected*;
- the eight control-flow forms are closed and the four runtime forms are **stated** blind spots;
- the `scenario.current` flag tags a record and only while it exists;
- the guard **fails open** — exit 0, no stdout, no stderr — under empty stdin, garbage stdin,
  a restricted PATH, an unwritable state dir, a null `cwd`, an unbalanced quote, no `python3`, and
  a `python3` that exists on PATH and exits 1 (the macOS xcselect stub).

Part A writes to a scratch `XDG_STATE_HOME`; it never touches the real decision log.

## What Part B proves

Part B is the half that cannot be faked: three things the design asserts from the docs and that had
never been exercised on this machine. Each is one `claude -p --plugin-dir /tmp/unity-ops-stage`
session against `ai_test`, dispatched **only** through `run_scenario.sh`, with the **real** state
dir (`unset XDG_STATE_HOME`) so records land where the metrics read them.

1. the hook fires at all inside a `--plugin-dir` headless session;
2. it fires for a tool call made by a **subagent**, and the record proves it was the subagent —
   a record whose `session_id` is not the parent's. "≥1 record appeared" is not enough: the parent could have produced it;
3. `additionalContext` actually reaches the model — falsified with a per-run nonce the model must
   quote, so a plausible paraphrase cannot be mistaken for receipt.

**This is the fork in the plan.** Part B is what DESIGN.md §4A rests on; if any of the three fails,
§4A falls back to §10 alternative C and this scenario records that instead of proceeding.

## Part B prompts

The three prompts are held verbatim in [`../briefs/hook.md`](../briefs/hook.md) and are dispatched from there.

**Observation 1 — the hook fires in a `claude -p --plugin-dir` session**

    Run exactly this and nothing else, then stop: unity status --format json

**Observation 2 — it fires for a tool call made by a subagent**

    Use the Agent tool to dispatch one general-purpose subagent. Its entire task: run 'unity command' (no arguments) once and report the first line of output. Do not run any unity command yourself.

**Observation 3 — `additionalContext` reaches the model**

    Write the single line 'probe' to /tmp/unity-ops-probe/Assets/Probe.unity. Then, before doing anything else, quote verbatim any guardrail or system-reminder context you received about that write. If you received none, say exactly: NO GUARDRAIL CONTEXT RECEIVED.

Observation 3's probe project is created under `/tmp` **before** the dispatch — the hook's `Write`
branch emits nothing when it can find no project, which would make the observation's own veto fire
deterministically and prove nothing. The probe must not write into `ai_test`.

## Legend

    OBS0 payload shape observed (json array | stream-json NDJSON)
    OBS1 hook fires in a claude -p --plugin-dir session
    OBS2 a record carries agent_id/agent_type identifying the subagent (R4-M4); session_id is shared with the parent on CLI 2.1.270
    OBS3 additionalContext reaches the model, nonce quoted

## Verdict

Each verdict is `OBSERVED` or `FAILED — FALLBACK §10 alternative C`, written unpadded, one per line:

    OBS0: __
    OBS1: __
    OBS2: __
    OBS3: __

The gate is `grep -c '^OBS[0-3]: OBSERVED$' ../results/hook.md`, which must print **4**.

## Fallback rule

If OBS1, OBS2 or OBS3 fails its stated criterion, write
`FAILED — FALLBACK §10 alternative C` on that line, finish the record and the commit anyway, and
**stop the increment**: DESIGN.md §4A falls back to §10 alternative C and `metrics.md` is rewritten
as manual protocols. Do not improvise a workaround. Do not re-run a failed observation more than
once unless the failure was a **harness** error (`run_scenario.sh` exit 2/3/4, or the stage failing
to load — `unity-ops` absent from the transcript's system/init plugin list is a harness failure, not
an observation failure), and say which it was. OBS2's criterion is the R4-M4 discriminator
(agent_id/agent_type on the record), not a distinct session_id — CLI 2.1.270 shares one session_id
between parent and subagent (observed 2026-09-14).
