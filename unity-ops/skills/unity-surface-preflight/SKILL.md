---
name: unity-surface-preflight
description: >
  Use when about to touch a Unity project for the first time in a session; before editing any
  scene, prefab, or asset file in a Unity repo; when a status probe reports no instances; when
  more than one Editor may be running; when a command returns AMBIGUOUS_EDITOR, exit 6, or times
  out; when deciding between running something headless and driving an open Editor.
---

# Unity surface preflight

Exactly one of four surfaces is true before you touch a Unity project — live Editor, batch, blocked-on-Safe-Mode, or unknown-and-must-ask — and you owe yourself evidence for the one you pick. The skill already loaded in this session catalogues each failure mode on its own page, hands you no rule for choosing between them, and at SK:184 lets a disclosed direct file edit follow the words "no reachable Editor" without asking you to rule out either way that conclusion goes wrong.

## The Iron Law

```
"NO EDITOR" IS A CONCLUSION, NOT A COMMAND OUTPUT. NEVER EDIT SCENE, PREFAB, OR ASSET YAML
UNTIL BOTH FALSE NEGATIVES ARE RULED OUT AND THE FALLBACK IS SAID OUT LOUD.
```

A probe you could not run is not a probe that came back empty. A denied tool call, a binary missing from `PATH`, a shell whose view of the machine you cannot vouch for — each leaves the surface **UNKNOWN**, and UNKNOWN is a question you put to the human. It is never a licence to open the YAML instead.

## The Gate

1. `pwd`. Confirm the directory you are calling the project root holds `ProjectSettings/ProjectVersion.txt`, read this session — not remembered from an earlier one.
2. Walk `references/decision-table.md` from the top and stop at the first predicate that matches. First match wins; do not skip a row because you expect its answer.
3. Name, in your response, the surface you resolved and the command output you resolved it from. One sentence, quoting the payload.
4. Only now act. No named surface, no serialized-asset edit.

If step 2 cannot finish because a probe was denied, errored, or was never available to you, the resolved surface is **UNKNOWN** and step 4 is "ask the human", not "fall back to the file". Inability to reach the CLI is the strongest reason to distrust "no Editor", not a shortcut past it.

## Red Flags — STOP

| Thought | Reality |
|---|---|
| "A status probe says no instances, so the Editor is closed." | Two different things produce that output and neither means "closed". (a) A sandboxed agent shell reproduces "no instances" against a *genuinely running* Editor — **this caveat does not exist in the skill you have loaded** (R1b §B/§D: GitHub-only). (b) A **headless/batch-launched** Editor serves commands and is *never* listed by `unity status` at all, because its lockfile heartbeat differs from a GUI Editor's — confirm reachability with `unity list --project-path <project>`, **not** `unity status` (IA:162-164) — and that probe answers in exactly two shapes, neither of them "empty": a tool catalog (151 entries in Increment 0), or `errors[0].code == "COMMAND_FAILED"`, `"No Pipeline instance found for project"`, at exit 6 (issue #27). |
| "Exit 6 means I have to pick an Editor." | Exit 6 covers more than one condition. `unity status --format json` with nothing running returns `success:false`, `data.count:0`, `data.instances:[]`, `errors[0].code:"STATUS_NO_INSTANCES"` — **observed on this machine by live probe; IA:337 carries only the `STATUS_NO_INSTANCES` code token, not the payload shape, and is not a citation for `data.count:0` [R4-M5]** — that is *no candidates*, not *too many*. `AMBIGUOUS_EDITOR` (SK:30; IA:21,44) is only the right branch when `data.candidates` is **non-empty**. Read `errors[0].code` and `data.candidates`, never the exit code alone. |
| "`unity pipeline list` will tell me if *this project* is in Safe Mode." | `pipeline list` is **machine-wide**. `unity pipeline list --help` lists no options of its own beyond `-h, --help` (a Global Options block prints after it — the CLI's shared set, not this subcommand's); passing `--project-path` returns `error: unknown option '--project-path'` and exit 2. The per-project answer is a **filter over `data.instances[]`** on the field carrying the project path — **observed in Increment 0 as `projectPath` (Delta D2)**. The machine-wide key is `data.summary.instancesInSafeMode`. And **`pipeline list` exits 0 even when it finds nothing** (observed: `success:true`, `data.instances:[]`, all six `summary` counters 0, exit 0) — while `unity status` with nothing running exits **6**. Gating on `pipeline list`'s exit code learns you nothing; read `data.summary`. |
| "Driving a fresh headless Editor gets me the same place." | It does not, and doing it silently is a substitution with no disclosure. The one sentence the installed skill gives you (SK:184) covers *disclosing a direct file edit*; it does not cover silently swapping control surfaces. |
| "The user says the Editor is open, so it is." | It may be, and the probe may still be blind to it — see row 1. A claim sitting in the task you were handed answers no question, because at that moment you had not asked one; it is the brief, not a reply. What counts is a human sentence that lands **after** all three probes, in this session, addressed to the question **you** put. Getting told up front makes asking more necessary, not less — that is the case where you would otherwise never ask at all. And even a real answer settles only the *sandbox* question, never that a project sits at state `ready`. |
| "`isRunning: true`, so a process is alive and only the bridge is down." | `isRunning` is a lockfile-and-heuristic field, not a look at the process table; `pipelineServer.isReachable` is the key that speaks to reachability. Watched on 2026-09-14 with the Editor shut and no Unity binary running at all: `{"isRunning":true,"hasPipelinePackage":true,"pipelineServer":{"isReachable":false,"apiUrl":null}}`, `summary.runningInstances: 1`, against `unity status` → `STATUS_NO_INSTANCES` (issue #30). When they disagree, `unity status` and `isReachable` carry it. A lone `isRunning: true` is not an instance, is not a broken bridge, and is not a reason to stay out of row 5. |

*Editor targeting, Safe Mode recovery and the never-hand-edit rule are the `unity-cli` skill's — read them there.*

## Guardrails

| Gated | Advisory in v1 | Hook pattern → promotion |
|---|---|---|
| Any `Edit`/`Write` to `**/*.unity`, `**/*.prefab`, `**/*.asset` under a dir containing `ProjectSettings/ProjectVersion.txt` `[restates SK:179 — adds: a glob-enforced gate and a disclosure requirement]` | Advisory: "preflight not run / surface unresolved — rule out the sandbox and Safe Mode, then say the disclosure sentence out loud" | `serialized-asset-write` → flip to `deny` after the 30-day window if the metric has not moved |
| Concluding "no Editor" from a single `unity status` | Require the machine-wide Safe-Mode check **and** `unity list --project-path` **and** the sandbox question before the conclusion | no pattern (reasoning, not a tool call) — measured via `serialized-asset-write` |
| `unity pipeline install` | **Never auto-run. Stop and ask.** Auto-allowed in `~/Dev/Unity/ai_test` only. SK:32 presents it as an ordinary setup step with no caution (*"add it once with `unity pipeline install`"*); that framing is what this row overrides. | `unity-invocation` → already an ask; stays an ask |
| `unity open` outside `~/Dev/Unity/ai_test` | Name the project and ask | `unity-invocation` → stays an ask |

## Evidence

| Claim | Requires | Not sufficient |
|---|---|---|
| "A live Editor is reachable for this project" `[restates SK:15, IA:326-337 — adds: the headless exception, which inverts the check]` | For a **warm/GUI** Editor opened via `unity open`: `unity status --format json` from this session with `data.instances[]` containing this project at state `ready` (IA:166-168). For a **headless/batch-launched** Editor: `unity list --project-path <project>` or `unity command`, because `unity status` will not list it at all (IA:162-164). | An earlier `status`; the Editor being visible in the Dock; the user saying it's open; `unity status` alone for a headless Editor |
| "No live Editor is reachable" | `unity status --format json` returning `errors[0].code == "STATUS_NO_INSTANCES"` **and** `unity list --project-path <project>` failing with `COMMAND_FAILED` (never "empty" — it has no such answer) **and** `unity pipeline list --format json` showing `data.summary.instancesInSafeMode == 0` **and** a human reply to the sandbox question **you** put, in this session, once those three probes were already behind you | `unity status` alone — that is two documented false negatives stacked. Nor does "the Editor is open" arriving in the task brief count: it precedes your question, so it is not a reply to it, and treating it as one is how a run reaches this claim having asked nobody anything |
| "This project is in Safe Mode" `[restates IA:355-361 — adds: the correct key path and the machine-wide scoping]` | `unity pipeline list --format json` → `data.summary.instancesInSafeMode > 0`, **then** the per-project filter over `data.instances[]` on `projectPath` (Delta D2), this session | `unity command` timing out. Note: `data.instances[].safeMode.detected` is documented at IA:360-361. Delta D3 filed it as a key whose value was JSON `null`; 2026-09-14 returned `"safeMode":{"detected":false,"confidence":"high"}` (Delta D14, issue #31). What has still never been seen in any payload is the shape this field takes when Safe Mode is **on** — so never test it for truthiness, and read `data.summary.instancesInSafeMode`, which is the only key this skill acts on. |
| "I am in the right project" | `pwd` + the resolved `--project-path` + `ProjectSettings/ProjectVersion.txt` read this session | Memory of the last project worked on |

The per-project filter, as Delta D2 recorded it — absolute path, no trailing slash, exact string compare, so run it from the project root or normalise both sides yourself:

```
unity pipeline list --format json | jq --arg p "$PWD" '.data.instances[] | select(.projectPath == $p)'
```

## Default invocation

The env envelope is defined once in `unity-ops:unity-cli-contract` and is not repeated here; probe calls additionally pass `--format json --no-pager` explicitly rather than trusting the env.

## Chain

- Entered from any Unity task, before the first action.
- Envelope and version probe: `unity-ops:unity-cli-contract` — run as a sub-step first.
- On LIVE → `unity-ops:unity-live-edit-verification`
- On BATCH → `unity-ops:unity-batch-hygiene`
- On Safe Mode → `unity-ops:unity-script-change-gate`
- Before any shutdown or cleanup command → `unity-ops:unity-destructive-gate`
- REQUIRED SUB-SKILL before claiming a surface is unreachable: `wolf-core:wolf-verification`
- Command reference, Safe Mode recovery, editor targeting (never restated here): the `unity-cli` skill.

## Decision table

Twelve predicates, evaluated in order, first match wins: `references/decision-table.md`. Read it there; do not reconstruct it from memory.
