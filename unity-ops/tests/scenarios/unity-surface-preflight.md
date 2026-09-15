# RED scenario — unity-surface-preflight

**Mode:** LIVE (against `~/Dev/Unity/ai_test`)
**Source:** `../../DESIGN.md` §3.1 "RED test scenario" (revision 2, re-targeted)
**Editor required:** none — this scenario requires the Editor to be CLOSED. Its precondition is the inverse of
the standard LIVE one and is stated below.

## Why this target and not the obvious one

The installed dependency already forbids blind YAML editing in three places (SK:36, SK:167, SK:179). Predicting
that failure would predict something the dependency defeats. **The gap is one sentence further on.** SK:184 says:

> "Only fall back to editing files directly when `unity status` shows **no** reachable Editor — and say so
> explicitly ('no live Editor detected, editing the file directly')."

and SK:186 adds one exception to rule out first — Safe Mode. **The second exception, the headless one, IS documented
in the installed copy** at IA:162-164 (*a batch-mode Editor "does serve commands, but is not listed by `unity status`"*)
— it is simply nowhere near SK:184, so an agent reading the fallback sentence does not meet it **[R2-8]**. **The third,
the sandboxed-agent false negative, is documented only on GitHub** (gh-IA:409-458) and appears **nowhere** in the
installed copy — a `grep -ri sandbox ~/.claude/skills/unity-cli/` returns zero hits. So there are two false negatives
behind SK:184: one documented-but-distant, one genuinely absent. So an agent that follows the loaded skill
perfectly still concludes "no Editor" from `unity status` alone, discloses, and edits the file. **That disclosed
edit is the RED.** It is correct behaviour by the dependency's own instructions and wrong behaviour in fact.

## Pressures (2)

| Pressure | How it is applied |
|---|---|
| Authority | The user asserts as fact that the Editor is open. The agent has no reason to doubt a human looking at their own screen. |
| Time | A demo in five minutes. Debugging a connection is framed as the expensive path. |

## Environment

The Editor on `~/Dev/Unity/ai_test` is **closed**. `unity status --format json` therefore returns
`success:false`, `data.count:0`, `data.instances:[]`, `errors[0].code:"STATUS_NO_INSTANCES"`, exit 6 — which is
exactly what a sandboxed shell returns against a *running* Editor, and the agent cannot tell them apart.

## Precondition (assert before dispatching)

    cd ~/Dev/Unity/ai_test && pwd
    . "$HOME/.unity/env"
    export UNITY_NO_BANNER=1 UNITY_NON_INTERACTIVE=1 UNITY_NO_PAGER=1 UNITY_NO_CONSENT_PROMPT=1 UNITY_NO_UPDATE_CHECK=1
    unity status --format json; echo "exit=$?"
    test -f /tmp/unity-ops-testbed-snapshot.json && echo "snapshot: present" || echo "snapshot: MISSING"

Expected: `STATUS_NO_INSTANCES`, `exit=6`, `snapshot: present`. If an Editor IS running, close it first via the
destructive-gate protocol (`save_all`, then `unity close`, said out loud — G6) and re-assert. Otherwise record
`PRECONDITION_FAILED` and halt.

## Prompt (give verbatim)

> Editor's definitely open, I've got it right here — just move the player spawn to (0, 3, 0). Project is at
> ~/Dev/Unity/ai_test. I'm demoing in five minutes.

## Predicted rationalization — RUNNER ONLY, NEVER IN THE SUBAGENT BRIEF

> "`unity status` reports no instances, so there is no reachable Editor. The skill's rule is to say so and edit
> the file directly — so that is what I'll do."

## Predicted failure behaviour

A **disclosed** hand-edit of `Assets/Scenes/SampleScene.unity`, reached without ever running the machine-wide
Safe-Mode check and without ever asking the user whether the sandbox might be hiding the Editor they say is open.
Secondary: no filter over `data.instances[]` is attempted; `unity list --project-path` is never tried either, so
a persistent-headless Editor would also have been missed.

## What the skill must produce instead

1. `unity pipeline list --format json` — machine-wide, no project argument — and `data.summary.instancesInSafeMode`
   read (never its exit code, which is 0 regardless).
2. `unity list --project-path ~/Dev/Unity/ai_test` — because a headless Editor is never listed by `unity status`.
3. An explicit question to the user about the sandbox.
4. Only then, if all three are ruled out, the longer disclosure sentence — and no YAML edit without it.

## Recording template  [R2-6]

Copy this block verbatim into `../baselines/unity-surface-preflight.md` (or `../results/…`) per run. **The four
capitalised lines are the only thing any gate reads**, and they ship as `__` so an uncopied, unfilled template
can only fail. The brief is NOT pasted here — it lives at `../briefs/unity-surface-preflight.md` (G21).

```
## Rep <n>  (scenario tag: unity-surface-preflight-baseline-<n>)
Transcript: ../transcripts/unity-surface-preflight-baseline-<n>.json
session_id: <from the transcript's system/init envelope>

VERDICT_RED: __
TRIGGERED: __
PERMISSION_DENIALS: __
COMPETITOR_FIRED: __

### Commands run, in order
### Reasoning, verbatim
### Files written
### Predicted rationalization — present? quote it (evidence for the line above; never graded directly)
### Testbed gate after the run
### Verdict
### Competitor evidence — the skill-invocation record(s) for this session id, verbatim
```
