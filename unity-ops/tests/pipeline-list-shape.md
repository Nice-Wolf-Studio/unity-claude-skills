# Observed shape of `unity pipeline list --format json`

**field observed: `data.instances[].projectPath`**

Observed 2026-09-14, CLI 1.0.0-beta.8, one warm Editor on `~/Dev/Unity/ai_test` (`com.unity.pipeline` 0.7.0-exp.1).
`pipeline list` takes **no project argument** (`--help` lists no options of its own beyond `-h, --help`; the Global Options block that prints after it is the CLI's shared set, not this subcommand's); `--project-path` produces `error: unknown option '--project-path'` with exit 2.
It exits **0 even when it finds nothing** — read `data.summary`, never the exit code.

## Per-project filter — the field, as observed
The project path is carried at `data.instances[].projectPath`. Filter with:

    jq --arg p "$PWD" '.data.instances[] | select(.projectPath == $p)'

Run for real from `/Users/jeremymiranda/Dev/Unity/ai_test`, that filter returned exactly 1 instance.
The value is an **absolute, non-trailing-slash** path string that compared equal to `$PWD` — no normalisation was needed in this observation. A skill invoked from a subdirectory of the project, or against a symlinked path, is NOT covered by this observation and must not assume equality holds.

Every `unity-ops` skill cites this path. If a future CLI moves it, this file is the single place to update.
Step 4's degradation branch did not fire: a per-project field exists, so decision-table row 1 may resolve per project instead of on the machine-wide counter.

## `safeMode.detected`
Observed: **absent**. Documented at IA:360-361. If absent, `data.summary.instancesInSafeMode` remains
the only confirmed Safe-Mode key and skills must say so.

Detail of the absence, so a later reader does not re-probe it:
- the `safeMode` key **is** present on the instance object, but its value is JSON `null` (`has_safeMode_key=true  safeMode_type=null`);
- `.data.instances[] | .safeMode.detected` therefore yields `[null]`, not a boolean;
- the literal string `detected` does not occur anywhere in the payload (`grep -c 'detected'` printed `0`).

Consequence: a skill must never test `.safeMode.detected` truthiness as if the key existed. With a NOT-in-Safe-Mode Editor, `safeMode` is `null` — the Safe-Mode-positive shape of this field has still never been observed, so what `safeMode` holds when an Editor IS in Safe Mode remains unknown and must not be guessed.

## Full scalar paths observed

    instances[0].projectName = ai_test
    instances[0].projectPath = /Users/jeremymiranda/Dev/Unity/ai_test
    instances[0].pid = 70572
    instances[0].isRunning = true
    instances[0].hasPipelinePackage = true
    instances[0].pipelineVersion = 0.7.0-exp.1
    instances[0].pipelineServer.port = 7800
    instances[0].pipelineServer.isReachable = true
    instances[0].pipelineServer.apiUrl = http://127.0.0.1:7800/api/editor_status

### Two keys that dump silently drops
The `paths(scalars)` dump above is **not** a complete key list. jq's `paths(f)` is `select(f)` over each node,
so a node whose value is `false` or `null` selects itself away. Enumerating with `to_entries` instead shows
two further keys on the same object:

    instances[0].updateAvailable : boolean = false
    instances[0].safeMode        : null    = null

Any later task that enumerates this shape must use `to_entries`, not `paths(scalars)`, or it will conclude
that `safeMode` is missing when it is in fact present-and-null.

Sibling key outside the array, for completeness: `data.latestVersion = 0.7.0-exp.1`.

## Summary keys

    summary.totalInstances = 1
    summary.runningInstances = 1
    summary.instancesWithPipeline = 1
    summary.reachableServers = 1
    summary.instancesInSafeMode = 0
    summary.instancesWithUpdateAvailable = 0

## Not to be confused with `unity list`
`unity list` is a **tool catalog**, not an instance list: it returns `command: "list"` with `data.target`
(host/port of the pipeline server), `data.count = 151` and `data.tools[]`. It answers nothing about which
Editors are running. Only `unity pipeline list` enumerates instances.
