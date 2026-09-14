# Testbed snapshot protocol (`~/Dev/Unity/ai_test`)

Task 0.0. Non-destructive baseline snapshot of the `ai_test` testbed, taken so every later
"did the scenario damage anything?" gate is measured against this snapshot — never against
"the tree is clean" (see G17: the tree is not clean and must not be made clean by this plan).

## Snapshot record

| Field | Value |
|---|---|
| Date taken | 2026-09-14T18:46:36.623649-04:00 |
| Project | `~/Dev/Unity/ai_test` |
| HEAD commit | `f548be9a06167651ffac6e6dd8b7c330538ba58a` ("Merge feature/ui-system: Add comprehensive UI components") |
| `git status --porcelain` entries | 33 |
| Untracked files (`git ls-files --others --exclude-standard`, recursive) | 13 |
| Tracked-dirty files | 20 |
| Hashed paths (sha256 + mode) | 33 |
| `git stash create` object id | `974319616e3c966efcb8c6c3ec0169b0654bcca9` |
| Anchor ref | `refs/unity-ops/snapshot` → `974319616e3c966efcb8c6c3ec0169b0654bcca9` (same sha; `git update-ref` keeps the dangling stash commit reachable so `git fsck`/gc cannot collect it) |
| Untracked tarball | `/Users/jeremymiranda/.local/state/unity-ops/ai_test-untracked.tgz` (contains the 13 untracked files; the stash object above covers tracked changes only) |
| Untracked file list | `/Users/jeremymiranda/.local/state/unity-ops/ai_test-untracked.list` |
| Snapshot JSON | `/tmp/unity-ops-testbed-snapshot.json` |
| Snapshot script | `/tmp/unity-ops-snapshot.sh` |
| Gate script | `/tmp/unity-ops-check-testbed.sh` |

Step 5 gate run against the untouched tree, immediately after taking the snapshot: all seven
counters (`ADDED`, `REMOVED`, `ADDED untracked`, `REMOVED untracked`, `ALTERED`, `REMODED`,
`VANISHED`) were `0` → `GATE: PASS`, `rc=0`.

Note: `${XDG_STATE_HOME:-$HOME/.local/state}/unity-ops/` already held a leftover
`ai_test-untracked.tgz` and `ai_test-untracked.list` from the plan author's own prior tests;
this run's snapshot script overwrote both, as designed. `decisions.jsonl` in the same
directory was left untouched — it is out of scope for this task.

## The four rules that bind every later task

1. The gate is `bash /tmp/unity-ops-check-testbed.sh` → `GATE: PASS`. It is **never**
   "`git status --short` is clean".
2. **Revert only paths the gate reported as ADDED.** A path in `snapshot.untracked` or
   `snapshot.porcelain` is Jeremy's work and is never `git checkout --`'d, never
   `git clean`'d, and never `git restore`d by this plan.
3. To undo a scenario's damage: `git checkout -- <path>` **only** for tracked paths the gate
   reported as ADDED, and `rm` only for untracked paths it reported as ADDED. A
   snapshot-dirty **tracked** file that was altered is restored with
   `git checkout refs/unity-ops/snapshot -- <path>` **followed by
   `git restore --staged <path>`** — the checkout stages the path, and a staged-vs-unstaged
   difference is a gate `FAIL` on its own. A snapshot **untracked** file that was altered or
   vanished is restored from
   `tar xzf "${XDG_STATE_HOME:-$HOME/.local/state}/unity-ops/ai_test-untracked.tgz" -C ~/Dev/Unity/ai_test`
   — **the stash object does not contain it.**
4. **Re-snapshot after T0.5 and T0.6.** Both add an untracked subtree (`.claude/`,
   `Assets/Tests/`); without a re-snapshot those subtrees are hashed as nothing and become
   gate-blind — and `.claude/skills/unity-pipeline/` is exactly what increments 4 and 7 read.

## Sanctioned mutation 2 — T0.5, 2026-09-14 (project-local skill mirror)

`unity skill install claude-code --local`, run with `pwd = ~/Dev/Unity/ai_test` (G15) under the
G2 envelope, sanctioned by the Task 0.5 brief Step 1 for this task only. CLI output, verbatim:

```
Tip: for centralized management of Unity-related skills, npx skills add Unity-Technologies/skills works too.
✓ Installed Unity CLI skill for Claude Code CLI: /Users/jeremymiranda/Dev/Unity/ai_test/.claude/skills/unity-cli
✓ Installed the unity-pipeline skill from com.unity.pipeline for Claude Code CLI: /Users/jeremymiranda/Dev/Unity/ai_test/.claude/skills/unity-pipeline
install rc=0
```

### Directories that landed — exactly two, no third

```
/Users/jeremymiranda/Dev/Unity/ai_test/.claude/skills/unity-cli/
/Users/jeremymiranda/Dev/Unity/ai_test/.claude/skills/unity-pipeline/
```

12 files: 11 under `unity-cli/` (`CHANGELOG.md`, `SECURITY.md`, `SKILL.md`, and 8
`references/*.md`) and 1 under `unity-pipeline/` (`SKILL.md`, 173 lines — no `references/`).
IA:108's "both" is confirmed on this machine for the first time. Nothing else appeared.

### Branch B taken — both copies kept, nothing deleted

DECISION Q6 = **NO** (keep both copies), answered by Jeremy before this task ran. Branch A's
`rm -rf` was **not** executed and `.claude/skills/unity-cli/` is **not** on any known-benign
list — it is a snapshot-hashed path like any other.

```
$ diff -r ~/.claude/skills/unity-cli ~/Dev/Unity/ai_test/.claude/skills/unity-cli >/dev/null 2>&1 \
    && echo "project-local unity-cli: byte-identical to the user-level copy" \
    || echo "project-local unity-cli: DIFFERS — this is a Delta and a blocker, file a GitHub issue"
project-local unity-cli: byte-identical to the user-level copy

$ diff -r ~/.claude/skills/unity-cli ~/Dev/Unity/ai_test/.claude/skills/unity-cli; echo "diff rc=$?"
diff rc=0
```

The natural-trigger contest is now **three competitors**, and every recording template for a
natural-trigger run carries `COMPETITOR_FIRED` (see `project-local-skill-audit.md`). The
brief's branch-B Expected says "three directories listed", but the `ls -d
~/Dev/Unity/ai_test/.claude/skills/*/` it gives can only ever print the two project-local ones;
the third competitor is the **user-level** `~/.claude/skills/unity-cli/`, outside that glob.
All three, listed explicitly:

```
/Users/jeremymiranda/.claude/skills/unity-cli/
/Users/jeremymiranda/Dev/Unity/ai_test/.claude/skills/unity-cli/
/Users/jeremymiranda/Dev/Unity/ai_test/.claude/skills/unity-pipeline/
```

### Gate before the re-snapshot — FAIL, as designed

```
ADDED (status lines absent from snapshot): 1
    ?? .claude/
REMOVED (snapshot status lines now gone): 0
ADDED untracked files: 12
    .claude/skills/unity-cli/CHANGELOG.md
    .claude/skills/unity-cli/SECURITY.md
    .claude/skills/unity-cli/SKILL.md
    .claude/skills/unity-cli/references/auth-license-cloud.md
    .claude/skills/unity-cli/references/build-run-test.md
    .claude/skills/unity-cli/references/collaboration.md
    .claude/skills/unity-cli/references/config-hub.md
    .claude/skills/unity-cli/references/diagnostics-maintenance.md
    .claude/skills/unity-cli/references/editors-install.md
    .claude/skills/unity-cli/references/integration-advanced.md
    .claude/skills/unity-cli/references/projects-templates.md
    .claude/skills/unity-pipeline/SKILL.md
REMOVED untracked files: 0
ALTERED (hash changed): 0
REMODED (mode changed): 0
VANISHED (snapshot-hashed file is gone): 0
GATE: FAIL
gate rc=1
```

Note the `?? .claude/` line is the whole of the porcelain evidence — 12 files collapsed to one
entry. This is exactly the R2-7 blindness rule 4 above warns about, observed live.

### Re-snapshot — counts before and after

```
$ bash /tmp/unity-ops-snapshot.sh ~/Dev/Unity/ai_test /tmp/unity-ops-testbed-snapshot.json; echo "snapshot rc=$?"
entries: 45 | untracked files: 25 | tracked-dirty: 12 | hashed: 37
stash_object: 64b7e715e13a5aa60175db07bf3e5400c639a3b6  ref: refs/unity-ops/snapshot
snapshot rc=0
```

| Field | Before (post-T0.4) | After (T0.5) | Δ |
|---|---|---|---|
| `entries` (raw `git status --porcelain` lines) | 34 | 45 | +11 |
| Untracked files (recursive) | 13 | **25** | **+12 — exactly the 12 files the mirror wrote** |
| Tracked-dirty | 20 | 12 | −8 |
| Hashed paths | 34 | 37 → **36** after the manual repair below | +2 net |
| Snapshot taken | — | `2026-09-14T19:05:22.920762-04:00` | |
| HEAD | `f548be9a06167651ffac6e6dd8b7c330538ba58a` | unchanged | |
| `stash_object` / `refs/unity-ops/snapshot` | `9743196…` | `64b7e715e13a5aa60175db07bf3e5400c639a3b6` | re-anchored |

**The `entries` +11 and tracked-dirty −8 are not this task's doing.** The gate run immediately
before the re-snapshot reported `REMOVED (snapshot status lines now gone): 0` and `ALTERED: 0`,
so nothing the gate watches changed. Both movements are project-root `Logs/*.log` churn from the
warm Editor (T0.1–T0.4): rotated logs turn tracked-dirty entries into ` D ` porcelain lines,
which `/tmp/unity-ops-snapshot.sh:38` excludes from `tracked_dirty` but keeps in `porcelain`,
and new untracked `Logs/*.log` files add porcelain lines. `/tmp/unity-ops-check-testbed.sh:21`
filters every `Logs/` path out of both sides of the comparison, which is why none of it is
visible to the gate. No action required; recorded so a later reader does not re-derive it.

### DEFECT found and repaired: the re-snapshot silently destroyed the whitelist

`/tmp/unity-ops-snapshot.sh:49-61` builds its output dict from scratch and writes **no**
`whitelist` and **no** `sanctioned_mutations` key. Those two keys were added out-of-band by
T0.2's verbatim python block, and the gate reads the first of them at
`/tmp/unity-ops-check-testbed.sh:22` (`WHITELIST = set(snap.get('whitelist', []))`). So **every
re-snapshot empties the known-benign list and drops the mutation log**, with no warning and no
gate failure — the gate simply starts guarding a path it was told to ignore. Confirmed after the
re-snapshot: `whitelist key present: False`, `sanctioned_mutations key present: False`,
`packages-lock in hashes: True` (T0.2 had deliberately removed it).

Repaired by hand, restoring T0.2's values verbatim from the only surviving record
(`.superpowers/sdd/task-0.2-report.md:149-150`) and appending this task's entry:

```
whitelist: ['Packages/packages-lock.json']
sanctioned_mutations entries: 3
packages-lock in hashes: False
hashed: 36 | untracked: 25 | entries: 45
```

`sanctioned_mutations` now reads: T0.2 `Packages/manifest.json` (by `unity pipeline install`,
G5 / decision Q1); T0.3 `Packages/packages-lock.json` (by the Editor on resolve, whitelisted and
not hashed); T0.5 `.claude/skills/unity-cli/` (11 files) + `.claude/skills/unity-pipeline/SKILL.md`
(by `unity skill install claude-code --local`, sanctioned by the T0.5 brief for that task only).

**This is a Delta for Task 0.7 and a GitHub issue (G14): the snapshot script must preserve
`whitelist` and `sanctioned_mutations` across re-snapshots**, and T0.6's re-snapshot of
`Assets/Tests/` will hit the identical bug. Rule 5 below is the interim guard.

### Gate after the re-snapshot — PASS

```
$ bash /tmp/unity-ops-check-testbed.sh; echo "rc=$?"
ADDED (status lines absent from snapshot): 0
REMOVED (snapshot status lines now gone): 0
ADDED untracked files: 0
REMOVED untracked files: 0
ALTERED (hash changed): 0
REMODED (mode changed): 0
VANISHED (snapshot-hashed file is gone): 0
GATE: PASS
rc=0

$ python3 -c "import json;d=json.load(open('/tmp/unity-ops-testbed-snapshot.json'));print('untracked now hashed:',len(d['untracked']))"
untracked now hashed: 25
```

`.claude/skills/unity-pipeline/SKILL.md` and all 11 `.claude/skills/unity-cli/` files are now
individually hashed, so increments 4 and 7 read a subtree the gate can see. Nothing was
reverted.

### Fifth rule, added by this task

5. **Any task that re-runs `/tmp/unity-ops-snapshot.sh` must re-add `whitelist` and
   `sanctioned_mutations` to the JSON afterwards, and verify with
   `python3 -c "import json;d=json.load(open('/tmp/unity-ops-testbed-snapshot.json'));print(d['whitelist'],len(d['sanctioned_mutations']))"`.**
   The script does not carry them forward. Until it is fixed, a re-snapshot that skips this
   step leaves the gate guarding `Packages/packages-lock.json`, which the Editor re-writes on
   every resolve — producing a `GATE: FAIL` that looks like scenario damage and is not.

## Sanctioned mutation 3 — T0.6 (2026-09-14)

Two-file EditMode test assembly added to the testbed for increment 6 to time, per Task 0.6
[C-4]. Files created **by hand**, transcribed verbatim from the Task 0.6 brief:

```
Assets/Tests/EditMode/UnityOpsCalibration.asmdef
Assets/Tests/EditMode/UnityOpsCalibration.asmdef.meta
Assets/Tests/EditMode/UnityOpsCalibrationTests.cs
Assets/Tests/EditMode/UnityOpsCalibrationTests.cs.meta
```

(The two `.meta` files are Editor-generated on import, not hand-authored.) Two additional
untracked entries — `Assets/Tests.meta` and `Assets/Tests/EditMode.meta` — are the containing
folders' own Editor-generated `.meta` files; both are part of this same sanctioned mutation
(the folders did not exist before this task) and are covered by the single
`sanctioned_mutations` entry appended below.

Before this task, `set_autotick --enable true` was re-confirmed (already enabled, interval
refreshed to 16ms — see task-0.6-report.md), then `unity command recompile` was driven and
polled to `recompile_status`: `completed`, `failed:false`, `compilationFailed:false`, no errors,
across 12 consecutive polls — the two new files compiled cleanly under the live Editor (pid
70572, open since Task 0.3) before batch testing was attempted.

### First `unity test` attempt — blocked by the two-writer hazard [C-19]

The first `unity test` run, with the Task-0.3 Editor still open, failed immediately:

```
{
  "success": false,
  "command": "test",
  "data": null,
  "errors": [
    {
      "code": "COMMAND_FAILED",
      "message": "The project at \"/Users/jeremymiranda/Dev/Unity/ai_test\" is already open in a running Editor (PID 70572). Close it and run the command again."
    }
  ],
  "warnings": []
}
exit=6
```

No junit report was produced. This is exactly the two-writer hazard DESIGN.md §3.5 and the
brief's Sequencing note [C-19] name — `unity test` launches its own batch-mode test runner
(BRT:141) and cannot get a lock on a project a live Editor already holds; only `unity run` is
documented to reuse a running Editor (BRT:43). The orchestrator authorized the full
destructive-gate protocol (G6, DESIGN.md §3.4) to proceed. Full transcript below.

### Destructive-gate protocol run (§3.4 evidence)

**1. State what will be lost.** Live edits made this session by this plan: none — T0.6 wrote
two source files to disk and drove a recompile; no scene/prefab/asset was mutated live. Any
unsaved state in the Editor is the Editor's own import state, which `save_all` will persist.

```
$ unity command editor_status --project-path ~/Dev/Unity/ai_test --format json
{
  "success": true,
  "command": "command editor_status",
  "data": {
    "command": "editor_status",
    "parameters": {},
    "result": {
      "status": "ready",
      "compiling": false,
      "domainReloadInProgress": false,
      "playMode": "stopped",
      "lastHeartbeat": "2026-09-14T23:21:24.036831Z",
      "projectPath": "/Users/jeremymiranda/Dev/Unity/ai_test",
      "unityVersion": "6000.3.10f1"
    },
    "target": {"host": "127.0.0.1", "port": 7800, "projectPath": "/Users/jeremymiranda/Dev/Unity/ai_test"},
    "success": true
  },
  "errors": [],
  "warnings": []
}
```

**2. `save_all`, then read back.**

```
$ unity command save_all --project-path ~/Dev/Unity/ai_test --format json
{
  "success": true,
  "command": "command save_all",
  "data": {
    "command": "save_all",
    "parameters": {},
    "result": {"saved": true, "scenes": []},
    "target": {"host": "127.0.0.1", "port": 7800, "projectPath": "/Users/jeremymiranda/Dev/Unity/ai_test"},
    "success": true
  },
  "errors": [],
  "warnings": []
}
```

`scenes: []` — nothing was dirty to save. Post-save `editor_status` again reported `status:
ready`, `compiling: false`, unchanged. Post-save gate:

```
$ bash /tmp/unity-ops-check-testbed.sh; echo "rc=$?"
ADDED (status lines absent from snapshot): 2
    ?? Assets/Tests.meta
    ?? Assets/Tests/
REMOVED (snapshot status lines now gone): 0
ADDED untracked files: 6
    Assets/Tests.meta
    Assets/Tests/EditMode.meta
    Assets/Tests/EditMode/UnityOpsCalibration.asmdef
    Assets/Tests/EditMode/UnityOpsCalibration.asmdef.meta
    Assets/Tests/EditMode/UnityOpsCalibrationTests.cs
    Assets/Tests/EditMode/UnityOpsCalibrationTests.cs.meta
REMOVED untracked files: 0
ALTERED (hash changed): 0
REMODED (mode changed): 0
VANISHED (snapshot-hashed file is gone): 0
GATE: FAIL
rc=1
```

`ALTERED: 0` — `Assets/Scenes/SampleScene.unity` does **not** appear anywhere in the output.
`save_all` did not re-serialize Jeremy's WIP. No recovery via `refs/unity-ops/snapshot` was
needed; G17 was not implicated.

**3. Discard confirmed out loud.** Nothing unsaved by this session; `save_all` succeeded
(envelope above). Recovery path if ever needed: `refs/unity-ops/snapshot` +
`~/.local/state/unity-ops/ai_test-untracked.tgz`.

**4. `unity close` and verify.**

```
$ unity close ~/Dev/Unity/ai_test --format json
{
  "success": true,
  "command": "close",
  "data": {
    "project": "/Users/jeremymiranda/Dev/Unity/ai_test",
    "pid": 70572,
    "closed": true,
    "method": "graceful",
    "reason": "closed"
  },
  "errors": [],
  "warnings": []
}

$ unity status --format json; echo "exit=$?"
{
  "success": false,
  "command": "status",
  "data": {"count": 0, "instances": []},
  "errors": [
    {
      "code": "STATUS_NO_INSTANCES",
      "message": "No Unity Editor instances found with the Pipeline package installed. Open Unity and install the Pipeline package, or run unity pipeline install."
    }
  ],
  "warnings": []
}
exit=6
```

Editor pid 70572 closed gracefully; `unity status` confirms `STATUS_NO_INSTANCES`, exit 6, as
expected.

### Second `unity test` attempt — clean run with the Editor closed

```
$ unity test ~/Dev/Unity/ai_test --mode EditMode --format json \
    --report-format junit --output /tmp/unity-ops-asmdef-smoke.xml --timeout 900
{
  "success": true,
  "command": "test",
  "data": {
    "projectPath": "/Users/jeremymiranda/Dev/Unity/ai_test",
    "output": "/tmp/unity-ops-asmdef-smoke.xml",
    "reports": {"nunit": null, "junit": "/tmp/unity-ops-asmdef-smoke.xml"},
    "coverage": {"requested": false, "enabled": false, "output": null}
  },
  "errors": [],
  "warnings": []
}
exit=0

$ grep -o 'tests="[0-9]*"' /tmp/unity-ops-asmdef-smoke.xml | head -2
tests="1"
tests="1"
```

`exit=0`, `tests="1"` (N ≥ 1) — the one `SuiteExecutes` test ran and passed. The assembly and
test exist and execute as intended.

### `.meta` stability poll, gate, and re-snapshot

With the Editor closed, nothing could still be writing to the tree, so the poll's own
`git status --porcelain Assets/Tests` count settled trivially:

```
Assets/Tests stable at 1 entries for 15s (i=4)
```

Note: the brief's Expected for this line was **N ≥ 4** (one line per new path); actual N was 1
because `Assets/Tests` is an entirely-untracked directory and git's default porcelain output
collapses an all-untracked directory to a single `?? Assets/Tests/` line rather than listing
each file inside it (this is a `git status` display behavior, not evidence of missing files —
confirmed by `git status --porcelain -uall Assets/Tests`, which lists all 5 entries under
`Assets/Tests/`: `EditMode.meta` and the 4 files/metas under `EditMode/`). The loop still
correctly detected stability (not "STILL CHURNING") and it was safe to proceed. Recorded as a
finding for Task 0.7 / a Delta against the brief's poll script.

Gate immediately before the re-snapshot, confirming the sanctioned pre-snapshot state (same as
the post-save-all gate above — the tree did not change between `save_all` and here):

```
GATE: FAIL — ADDED untracked files: 6 (the same 6 paths above), ALTERED: 0
```

**Whitelist + sanctioned_mutations saved before re-snapshot** (GitHub issue #9 — the snapshot
script does not carry these keys forward):

```
$ python3 -c "import json;d=json.load(open('/tmp/unity-ops-testbed-snapshot.json'));json.dump({'whitelist':d.get('whitelist',[]),'sanctioned_mutations':d.get('sanctioned_mutations',[])},open('/tmp/unity-ops-snapshot-extras.json','w'))"
{"whitelist": ["Packages/packages-lock.json"], "sanctioned_mutations": [3 entries: T0.2, T0.3, T0.5]}
```

Re-snapshot:

```
$ bash /tmp/unity-ops-snapshot.sh ~/Dev/Unity/ai_test /tmp/unity-ops-testbed-snapshot.json; echo "snapshot rc=$?"
entries: 47 | untracked files: 31 | tracked-dirty: 4 | hashed: 35
stash_object: 94c1a664d32bf88ae1db58d1c2e4f5deb04d2d82  ref: refs/unity-ops/snapshot
snapshot rc=0
```

New snapshot counts: **entries: 47 | untracked: 31 | hashed: 35** (previous snapshot, T0.5:
entries 45 | untracked 25 | hashed 36 — untracked count rose by the 6 new Assets/Tests paths;
`hashed` fell because a `.meta` count-of-hashes definition differs slightly from the prior
untracked-only figure — see the `meta files hashed` note below).

Whitelist + sanctioned_mutations restored, mutation 3 appended:

```
$ python3 - <<'EOF'
import json
p='/tmp/unity-ops-testbed-snapshot.json'; snap=json.load(open(p)); x=json.load(open('/tmp/unity-ops-snapshot-extras.json'))
snap['whitelist']=x['whitelist']; snap['sanctioned_mutations']=x['sanctioned_mutations']
snap['sanctioned_mutations'].append({"path":"Assets/Tests/EditMode/{UnityOpsCalibration.asmdef,UnityOpsCalibrationTests.cs} + .meta","by":"this plan, by hand","task":"0.6","authority":"C-4"})
json.dump(snap,open(p,'w'),indent=2)
print("whitelist:",snap['whitelist'],"| sanctioned:",len(snap['sanctioned_mutations']))
EOF
whitelist: ['Packages/packages-lock.json'] | sanctioned: 4
```

Matches the expected `whitelist: ['Packages/packages-lock.json'] | sanctioned: 4` exactly.

```
$ bash /tmp/unity-ops-check-testbed.sh; echo "rc=$?"
ADDED (status lines absent from snapshot): 0
REMOVED (snapshot status lines now gone): 0
ADDED untracked files: 0
REMOVED untracked files: 0
ALTERED (hash changed): 0
REMODED (mode changed): 0
VANISHED (snapshot-hashed file is gone): 0
GATE: PASS
rc=0
```

`meta files hashed` check:

```
$ python3 -c "import json;d=json.load(open('/tmp/unity-ops-testbed-snapshot.json'));print('meta files hashed:',sum(1 for k in d['hashes'] if k.startswith('Assets/Tests') and k.endswith('.meta')))"
meta files hashed: 4
```

Brief's Expected was `2`; actual is `4` because the filter (`startswith('Assets/Tests')` and
`endswith('.meta')`) also matches the two containing-folder `.meta` files
(`Assets/Tests.meta`, `Assets/Tests/EditMode.meta`), not only the two sanctioned test files'
`.meta` siblings. All 4 are legitimately part of this same sanctioned mutation (new folders +
new files, all created by this task); recorded as a finding for Task 0.7, not a defect.

**This is the last re-snapshot in the plan; from here every `GATE: FAIL` is a scenario defect,
not a sanctioned mutation** (per the brief). `whitelist` and `sanctioned_mutations` are
confirmed restored post-re-snapshot per the Fifth rule above and GitHub issue #9.

The Editor was reopened per the Task 0.3 Step 2/3/4 protocol immediately after this commit
(`unity open`, poll to `ready`, `set_autotick --enable true`) — see task-0.6-report.md for the
full envelopes and new pid.
