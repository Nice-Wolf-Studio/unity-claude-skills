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
