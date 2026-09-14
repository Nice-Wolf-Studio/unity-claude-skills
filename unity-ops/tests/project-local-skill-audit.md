# Audit of the project-local `unity-pipeline` skill (Task 0.5)

Materialized into `~/Dev/Unity/ai_test/.claude/skills/` by
`unity skill install claude-code --local` on 2026-09-14 (sanctioned mutation 2, see
`testbed-snapshot.md`). Task 0.7 reads this file for Deltas D4–D7.

**Scope of the read.** `find … -type f` over `.claude/skills/unity-pipeline/` returns exactly
one file: `SKILL.md`, **173 lines**. There is no `references/` directory, no `CHANGELOG.md`,
no `SECURITY.md`. Every anchor below is `SKILL.md:<line>` in that file, cited as `UP:<line>`.
The whole file was read; every claim here is quoted from it.

---

## Step 2 — the five questions

### Q1. Does it document a read-back / verification pattern after a live mutation?

**NO for state read-back. PARTIAL for async-completion polling.**

There is no scene/object read-back anywhere in the file. `grep -niE 'get_|query|inspect|hierarchy|describe'`
returns only `*_status` polling commands. The words `save`, `persist`, `dirty` and `scene` appear
**once between them** in the whole file, and that one hit is unrelated:

> UP:91 — ``(default 30000), `--assemblyDir <dir>` (persist DLLs instead of in-memory);``

No `find_gameobjects`, no `get_scene_hierarchy`, no `save_scene`, no `save_all`, no
`create_gameobject`/`set_transform`/`add_component`. The skill's subject is the
**edit → recompile → test** loop and runtime code reload, not scene mutation.

What it *does* carry is completion polling, and one general anti-pattern sentence:

> UP:170-171 — ``- **Async commands poll.** `recompile`→`recompile_status`, `run_tests --async_tests`→``
> ``  `test_status`. Never assume completion from the trigger call's response.``

> UP:90 — ``​`unity command codereload_status` shows active overrides.``

> UP:107 — ``unity command run_script --file AgentScripts/Build.cs --dry_run true   # compile-only check: diagnostics, nothing loaded or executed``

**Effect on `unity-ops:unity-live-edit-verification` (DESIGN.md §3.2).** Its additive margin
**does not shrink** for the two halves that carry the Iron Law — *fresh read-back of the new
state* and *a save has persisted it* (DESIGN.md:239). Both are absent from `unity-pipeline`
entirely, and the save half is absent even as a word. The **evidence table rows** at
DESIGN.md:265-268 (`find_gameobjects`/`get_scene_hierarchy` after the mutation; `save_scene`
returning success plus a post-save read-back) are fully additive against this skill as well as
against `unity-cli`.

One row is now *adjacent to* competing text and should be re-classified as such rather than as
fully additive: the rationalization row **"`success: true`, so the GameObject exists"**
(DESIGN.md:245) shares its shape with UP:171's "Never assume completion from the trigger call's
response." UP:171 is scoped to **async completion** (did the command finish), not to **state**
(is the scene now what you think) — a narrower claim — but a grader reading the loaded skill
could plausibly generalize it. Recommend Task 4.3 keep the row and add the UP:171 pointer, the
way §3.3 points at the installed skill's Safe Mode section.

---

### Q2. Does it document `recompile_status` outside the `[CliCommand]`-authoring context?

**YES — unambiguously, and this is the most consequential finding of the task.**

`grep -c 'CliCommand'` over the file returns **0**. The string `[CliCommand]` does not occur
anywhere in `unity-pipeline/SKILL.md`. `recompile_status` occurs **three times**, all inside
the skill's headline workflow, `## 2. Autonomous edit loop (Editor)` (heading at UP:21):

> UP:32-36
> ```
> # 3. Recompile (async: triggers a domain reload, then poll until done).
> unity command recompile
> unity command recompile_status    # repeat until "completed" or "up_to_date"
> #   Tolerate connection errors while the domain reload is in flight — that is expected.
> #   If recompile_status reports failed=true, read its "errors" array and fix before testing.
> ```

> UP:170-171 — ``- **Async commands poll.** `recompile`→`recompile_status` … Never assume completion from the trigger call's response.``

So the primitive is presented as **step 3 of 5 in the general agent edit loop**, in a section
whose own preamble (UP:23) reads *"This is the core agent workflow: keep the editor alive,
change code, recompile, test."* The terminal states are named (`completed` / `up_to_date`), the
failure field is named (`failed=true`, read `errors`), the domain-reload connection error is
pre-excused, and the "fix before testing" ordering is stated.

**Effect on `unity-ops:unity-script-change-gate` (DESIGN.md §3.3).** DESIGN.md:285 states the
skill's entire reason to exist:

> "**`recompile_status` — the only way to know it finished — occurs exactly once in the entire
> skill, at IA:460, inside the `#### Authoring custom [CliCommand] tools` section (heading
> IA:426).** … That split is the whole gap."

That claim is **true of the `unity-cli` dependency and false of the environment the skill will
actually load in.** Inside `ai_test` — which per DESIGN.md §4B is where *every* LIVE scenario in
increments 2–7 runs — a second skill is loaded that documents the primitive generally, with
semantics, in its flagship workflow. The RED scenario at DESIGN.md:322 is built on the exact
inference this file defeats: *"`recompile` is documented as part of authoring a `[CliCommand]` —
I'm not authoring one … so that step doesn't apply."* A baseline agent with `unity-pipeline`
loaded has UP:32-36 in front of it and no `[CliCommand]` framing to be trapped by.

**Recommended classification for Task 0.7: Delta, cut-candidate — not an automatic cut.** Two
halves of §3.3 survive `unity-pipeline` intact and should be weighed before the skill is
deleted:

| §3.3 element | Covered by `unity-pipeline`? | Evidence |
|---|---|---|
| `recompile` → poll `recompile_status` until `completed` | **YES, fully** | UP:32-36, UP:170-171 |
| Terminal states, `failed=true`, read `errors` first | **YES** | UP:34, UP:36 |
| The `.cs`-write → `attach_script`-without-waiting trap (DESIGN.md:294, IA:301 chain) | **NO** | `attach_script`, `create_script`, `add_component` are absent from the file (0 hits) |
| Claim gate — "it compiles" requires the `recompile_status` payload quoted (DESIGN.md:313) | **NO** | no claim/evidence framing anywhere |
| Safe Mode as first hypothesis within 1 min of a `.cs` write (DESIGN.md:298, :306) | **NO — and actively contradicted**, see Q5-C | `Safe Mode` 0 hits; UP:162 names a different first hypothesis |
| `recompile --timeout 180` (DESIGN.md:320) | **NO** | no timeout guidance on `recompile`; the only `--timeout` is `reload_file`'s 30000 ms default (UP:90) |

The honest summary: **the primitive gap closes; the discipline gap does not.** §3.3's RED
scenario as written at DESIGN.md:322 is likely now un-runnable and must be re-targeted or the
skill re-scoped to the `attach_script`/claim-gate/Safe-Mode-ordering residue.

---

### Q3. Does it list this project's custom `[CliCommand]` catalog?

**NO.** Zero `[CliCommand]` hits. The skill lists no project-specific commands at all — it
documents the **package's** generic command surface in prose, and explicitly defers the full
list twice, to runtime discovery and to a file it does not ship:

> UP:8-11 — ``Invoke commands with `unity command <name> [args]`. Run `unity command` with no name to``
> ``list what an instance exposes. Two servers exist: **Editor** (`7800-7849`, auto-starts with``
> ``the editor) and **Runtime** (`7900-7949`, only in a dev Player build). See the package``
> ``​`README.md` "Commands" reference for the full list and parameters.``

**For `references/readback-catalog.md` (Task 4.3), the usable yield is the command *names* this
file names, and their server (Editor vs Runtime), because that pairing is not in `unity-cli`:**

| Command | Server / context | Anchor |
|---|---|---|
| `editor_status` | Editor; answers instantly even when the main thread is blocked | UP:18, UP:163-165 |
| `set_autotick --enable true` | Editor; **required before headless work** | UP:28, UP:160-161 |
| `recompile`, `recompile_status` | Editor | UP:33-34 |
| `list_tests --mode editor\|playmode\|all` | Editor | UP:39 |
| `run_tests` (`--mode`, `--filter`, `--filter_type`, `--async_tests`), `test_status`, `cancel_tests` | Editor | UP:42, UP:45-47 |
| `editor_play` | Editor | UP:66, UP:167 |
| `reload_file --filename [--pdb] [--timeout <ms>] [--assemblyDir <dir>]`, `codereload_status`, `cleanup_codereload --assemblyDir` | live game (Play Mode or dev Player), Mono only, not IL2CPP | UP:71-92 |
| `run_script --file --entry [--args] [--dry_run] [--defines] [--references] [--mode hotpatch] [timeout_ms]` | Editor | UP:94-123 |
| `eval`, `eval_file` | labelled **(Runtime)** — see Q5-B | UP:125-133 |
| `audit`, `audit_status` | Editor; needs Project Auditor **+ rules** | UP:135-156 |
| `package_add --identifier <pkg> --confirm true` | Editor — see Q5-A | UP:154-155 |
| `log`, `set_timescale`, `runtime_status` | **Runtime server only — does not run in the Editor** | UP:168-169 |
| `--instance host:port` / `--project-path <path>` targeting | any | UP:172-173 |

Note UP:8-9's *"Run `unity command` with no name to list what an instance exposes"* is the same
runtime-discovery rule DESIGN.md:273 and :297 already take as authoritative (`unity command
--format json`, IA:303). No conflict; a second independent source for it.

---

### Q4. Does it define an `undo` primitive?

**NO. `grep -nic 'undo'` over the file returns `0`.** Not a command, not a word, not a concept.

**DESIGN.md §3.2's claim survives contact with the third copy and needs no softening.**
DESIGN.md:248 asserts: *"There is **no `undo` command** — not in the catalog, not anywhere in
the installed copy, and not on GitHub@main either (R1b §B). Your only rollback is a reverse
mutation you wrote yourself, or git."* The project-local `unity-pipeline` skill is the one
source R1b never examined, and it is also silent. The Iron Law stands as written.

Two rollback-adjacent things exist and are **not** undo, recorded so they are not mistaken for
it later:

- `cleanup_codereload --assemblyDir <dir>` (UP:92) — "clears old DLLs", i.e. deletes persisted
  hot-patch assemblies. It does not revert an applied `[CodeReload]` override.
- `run_script --dry_run true` (UP:107) — "compile-only check: diagnostics, nothing loaded or
  executed." That is a *pre*-flight, not a rollback, and it exists only for `run_script`.

---

### Q5. Does it contradict anything in DESIGN.md §3 or §4?

**YES — three contradictions and one gap. A, C and D are material.**

#### A. `package_add` contradicts decision-table row 8 and the `unity-package-management` cut. **[material]**

DESIGN.md §4 row 8 (DESIGN.md:510):

> | 8 | The action needs a UPM package added or removed | **NEITHER** — out of CLI scope entirely | R1b §E G11; route to Unity's `unity-package-management` skill |

and DESIGN.md:162 justifies cutting a `unity-package-management` skill as *"**Confirmed by
absence** — no package-management command anywhere in the installed copy."*

The project-local skill documents one, in an imperative, with the confirm flag filled in:

> UP:152-156
> ```
> > **Requires Project Auditor plus its rules.** `unavailable` means the Editor has no Project Auditor,
> > or it has no analysis rules — in a built-in-module Editor the rules live in the separate
> > `com.unity.project-auditor-rules` package (`unity command package_add --identifier
> > com.unity.project-auditor-rules --confirm true`). Read the `message` field; …
> ```

"Confirmed by absence" was confirmed against the wrong corpus. Inside `ai_test`, `package_add`
is a documented, loaded, CLI-reachable UPM mutation. Row 8 would route an agent to "out of CLI
scope entirely" while the skill next to it shows the command that does it — and because the
decision table is first-match-wins and row 8 sits below the LIVE rows, the mis-route is silent.
**Row 8's predicate and its "Why" cell both need re-checking against `package_add`'s actual
scope (it may be Project-Auditor-rules-specific, or general — UP does not say).** Additionally,
`package_add … --confirm true` is a `--yes`-shaped auto-confirm flag on a mutating command, which
is the exact class G6 forbids and `unity-ops:unity-destructive-gate` (DESIGN.md §3.4) gates; it
is currently in **no** guardrail table.

#### B. `eval`/`eval_file` are labelled **(Runtime)**, which cuts against §3.2's guardrail framing. **[flag, do not act — the file is self-inconsistent here]**

DESIGN.md:256 and :259 gate `unity command eval` / `eval_file` as live-**Editor** mutations
(`live-eval` hook pattern, candidate `deny`), and DESIGN.md:249 describes them as running
"arbitrary C# at full local-user privilege". `unity-pipeline` heads that section:

> UP:125 — `## 5. Quick C# eval (Runtime)`

and its gotcha states:

> UP:168-169 — ``- **Player-only commands need a dev Player.** `log`, `set_timescale`, `runtime_status`, etc. hit``
> ``  the Runtime server, which does not run in the Editor.``

If `eval` truly is Runtime-server-only, §3.2's eval guardrails fire against a surface a plain
Editor does not serve. **This is flagged, not asserted**, for two reasons: (1) the `(Runtime)`
label is only in a heading, and UP:168's explicit Runtime-only list is `log`, `set_timescale`,
`runtime_status` — `eval` is *not* in it; (2) the file has a **duplicate section number** —
`## 5. Quick C# eval (Runtime)` at UP:125 and `## 5. Project audit (Editor)` at UP:135 — which
is a defect in Unity's shipped file and makes the parenthetical labels unreliable. **Resolution
requires a live probe** (`unity command eval "return 2+2;"` against the warm `ai_test` Editor);
that is a one-line addition to a later LIVE increment, not something to decide from the doc.
DESIGN.md:249's own caveat already covers the safe reading: `eval`/`eval_file` are
package-provided, optional, and must be discovered at runtime (IA:305-309).

#### C. First hypothesis for "the Editor stopped answering" conflicts with §3.3. **[material]**

DESIGN.md:298 (§3.3 rationalization) and DESIGN.md:306 (guardrail row 3):

> "Within one minute of a `.cs` write, the first hypothesis is **Safe Mode**, not a crash. Run
> the machine-wide Safe-Mode check before any other diagnosis."

`unity-pipeline` names a different first hypothesis for the same symptom, and `Safe Mode` has
**zero** hits in the file:

> UP:162-165
> ```
> - **A stuck command may mean a modal dialog is open**, not a hang — a dialog blocks the main
>   thread until dismissed. If a command runs long, check `unity command editor_status` (answers
>   instantly even when blocked); `status: "blocked_by_dialog"` means stop retrying and tell the
>   human what's blocking (its `dialog.title`/`message`/`buttons`) — it can't be clicked over CLI.
> ```

Two skills loaded in the same project give two different first moves for one observable. This is
not a flat contradiction — both hypotheses are real and they are cheaply *composable* — but
§3.3's guardrail says "before any other diagnosis", which excludes UP:163's check by
construction. **`blocked_by_dialog` is additive information §3.3 does not have** (`editor_status`
answering instantly while the main thread is blocked is a genuinely better first probe than
either hypothesis). Recommended resolution for Task 0.7: fold it in as an ordering —
`editor_status` first (it is non-blocking and disambiguates), *then* Safe Mode inside the
one-minute-after-`.cs`-write window, *then* crash — rather than leaving two competing "first"s.

#### D. `set_autotick` is absent from §4B's LIVE precondition list. **[material gap, not a contradiction]**

DESIGN.md §4B "The precondition every LIVE scenario asserts" (DESIGN.md:787-794) lists six
assertions: cwd + `ProjectVersion.txt`; `unity status` shows `ready`; or `unity list
--project-path` for headless; snapshot current; `claude auth status`; `stage.sh` succeeded.
**None of them is `set_autotick`.** `unity-pipeline` states it twice, as a hard precondition:

> UP:26-28
> ```
> # 1. Keep the editor ticking even when unfocused/minimized. REQUIRED before headless work —
> #    Unity otherwise throttles or stalls update/compile when it isn't the active app.
> unity command set_autotick --enable true
> ```

> UP:160-161 — ``- **`set_autotick` first.** Without it, recompile and tests can hang while the editor is``
> ``  unfocused. The package's watchdog relies on the tick loop staying alive.``

Every LIVE scenario in increments 2–7 drives a warm `ai_test` Editor from a headless
`claude -p` session — i.e. an Editor that is by definition **not the active app**. On UP's
account, a recompile or test run in that state "can hang". A scenario that hangs produces a
transcript that is not the test that was intended — exactly the `PRECONDITION_FAILED` failure
mode §4B exists to make impossible (DESIGN.md:800). **Recommendation: add
`unity command set_autotick --enable true` to the §4B bootstrap, as a runner step alongside
`unity open`, and record its response as precondition evidence.** Note this is a *mutating*
`unity command` against `ai_test` and so needs the same G5-class sanction `unity open` has.

#### Non-contradictions checked and cleared

- **Exit codes.** UP:56-61 (`2` = bad arguments, nothing ran; `6` = ran and failed / the Editor
  could not service it; "Do not retry an exit 2 unchanged, and do not rewrite a command line on
  an exit 6") is consistent with DESIGN.md §4 rows 3a and 4 and with G19. It is, however, a
  **restatement source** for `unity-ops:unity-cli-contract`'s description trigger *"Use when a
  unity command fails with exit 2"* (DESIGN.md:115) — see Step 3.
- **Runtime discovery of the catalog.** UP:8-9 agrees with DESIGN.md:273/:297.
- **`--project-path` / `--instance` targeting** (UP:172-173) agrees with DESIGN.md §4 row 4.
- **`undo`** — see Q4; agrees with DESIGN.md:248.

---

## Step 3 — trigger-collision analysis

### The frontmatter, verbatim

```
name: unity-pipeline
description: Drive a running Unity Editor or development Player from the command line via the unity-pipeline package — install the package, keep the editor ticking while unfocused, run the edit→recompile→run_tests loop, evaluate C#, and code-reload files at runtime. Use when an agent needs to control a live Unity instance, automate Unity tests, recompile scripts headlessly, or apply runtime reloads. Assumes the `unity` CLI is on PATH.
```

Shape notes, because they change how it competes: it is a **capability** description, not a
trigger description. It **leads with the workflow summary** ("Drive a running Unity Editor…")
and only reaches `Use when` in its second sentence — the inverse of G9, which requires every
`unity-ops` description to *start* with `Use when` and to list **triggers only**. It also
contains three of `unity-ops`'s own forbidden tokens in spirit ("Unity CLI" as `unity` CLI,
"install the package"). This is not a defect in Unity's skill — G9 binds `unity-ops`, not them —
but it means the two families are optimizing for different router behaviour, and a
capability-shaped description that names a whole workflow tends to win broad, vague prompts.

### Overlap against the six (DESIGN.md §2 catalog, DESIGN.md:110-115)

| `unity-ops:` skill | Overlapping `unity-pipeline` phrase | Severity | Why |
|---|---|---|---|
| `unity-script-change-gate` | "run the edit→recompile→run_tests loop", "**recompile scripts headlessly**", "automate Unity tests" | **HIGH — direct collision** | Its description triggers on *"a .cs file … has just been written or changed … before claiming it compiles, runs, is attached, or is testable"*. "recompile scripts headlessly" is the same moment stated as a capability. Combined with Q2 (the body actually documents the primitive), this is the one pairing where `unity-pipeline` both **out-triggers** and **out-covers** the `unity-ops` skill. |
| `unity-live-edit-verification` | "**control a live Unity instance**", "Drive a running Unity Editor", "apply runtime reloads" | **HIGH — trigger collision, no content collision** | Its description triggers on named mutation commands (`create_gameobject`, `set_transform`, …) which `unity-pipeline` never mentions, so a *specific* prompt should still route correctly. But a vague live-Editor prompt ("change the player's speed in the running editor") matches "control a live Unity instance" far better than it matches a command list. Per Q1 the bodies do **not** overlap — so a mis-route here loses the read-back/save discipline entirely and silently. This is the highest-consequence collision even though Q2's is the most certain. |
| `unity-batch-hygiene` | "**automate Unity tests**", "run_tests loop" | **MEDIUM** | Its description triggers on *"about to start a Unity build, test, or run from the command line"*. `unity-pipeline` claims the test half of that surface explicitly — and steers it to the **live** `unity command run_tests` rather than the batch `unity test` shape the skill exists to enforce. Note the two are genuinely different surfaces, so this is a real routing decision being made by description-matching rather than by the §4 decision table. |
| `unity-surface-preflight` | "Drive a **running** Unity Editor **or development Player**", "control a live Unity instance" | **MEDIUM** | Preflight's job is to *decide* batch-vs-live before anything runs. `unity-pipeline` presupposes the live answer in its first five words. A prompt that should enter preflight ("I need to change something in my Unity project") can be pulled straight to the live branch, skipping row 0 (dependency stop), row 1 (Safe Mode) and row 5 (sandbox false negative). |
| `unity-cli-contract` | "Assumes the `unity` CLI is on PATH", plus the body's exit-2/exit-6 table (UP:53-61) | **LOW–MEDIUM** | Description overlap is thin (the PATH sentence is an assumption, not a trigger). Body overlap is real: UP:56-61 restates the exit-code reading `unity-cli-contract` triggers on. Cross-check against conformance check 7's restatement audit — the `unity-cli-contract` rows that were kept should be re-tested against UP:53-61 as well as against SK/IA. |
| `unity-destructive-gate` | — none | **NONE** | No `close`, no `clean`, no `prune`, no `pkill`, no `--yes`/`--force` in the description. One body-level adjacency only: `package_add … --confirm true` (UP:154-155, Q5-A), which is a *gap* in the gate's coverage, not a collision. |

### Why this matters operationally (C-8)

`unity-pipeline` is **project-local to `ai_test`**, so it competes nowhere else on this machine —
and `ai_test` is where **every** LIVE scenario in increments 2–7 runs (DESIGN.md §4B). The
collision is therefore not hypothetical background noise: it is present in **100% of the
natural-trigger result runs**, and absent from any manual reading of the six descriptions done
outside the testbed. A GREEN verdict measured in `ai_test` is measured against this competitor
whether or not the grader knows it.

### The contest, as it now stands — three competitors (branch B)

| # | Skill | Location | Lines | Notes |
|---|---|---|---|---|
| 1 | `unity-cli` | `~/.claude/skills/unity-cli` (user-level) | 441 (SKILL.md), 11 files | beta.8-pinned |
| 2 | `unity-cli` | `~/Dev/Unity/ai_test/.claude/skills/unity-cli` (project-local) | identical | `diff -r` vs #1 → **byte-identical, rc=0** |
| 3 | `unity-pipeline` | `~/Dev/Unity/ai_test/.claude/skills/unity-pipeline` | 173 (SKILL.md), 1 file | audited above |

Per the brief, **branch B** was taken (Q6 = keep both copies); nothing was deleted. Every
natural-trigger recording template therefore gains:

```
COMPETITOR_FIRED: __        # unity-ops:<name> | unity-cli (user) | unity-cli (project-local) | unity-pipeline | none
```

filled from the hook's `skill-invocation` record joined on that run's session id (metric 7),
never from the grader's impression — for all three baseline reps and both result runs. Because
#1 and #2 are byte-identical, the router's choice *between them* is not interpretable; which
**family** won is, and that is all the GREEN / `TRIGGER-FAIL` verdict needs.

---

## Deltas proposed to Task 0.7

| ID | Delta | Anchor | Severity |
|---|---|---|---|
| D-a | `unity-script-change-gate`'s core gap (DESIGN.md:285) is closed **inside `ai_test`** by UP:32-36; the skill becomes a cut-candidate and its RED scenario (DESIGN.md:322) is likely un-runnable as written. The `attach_script` trap, the claim gate and the Safe-Mode ordering survive. | UP:32-36, UP:170-171 vs DESIGN.md:285, :313, :322 | **HIGH** |
| D-b | `unity-live-edit-verification` keeps its full additive margin (no read-back, no save, no `undo` in UP); re-classify one rationalization row against UP:171. | UP:171, UP:91 vs DESIGN.md:239, :245, :265-268 | MEDIUM |
| D-c | Decision-table row 8 ("UPM is out of CLI scope entirely") and the `unity-package-management` "confirmed by absence" cut are both falsified by `package_add`; `--confirm true` is an unguarded auto-confirm on a mutating command. | UP:154-155 vs DESIGN.md:510, :162, G6 | **HIGH** |
| D-d | §4B's LIVE precondition list omits `set_autotick`, which UP calls REQUIRED for unfocused/headless work; every increment 2–7 LIVE run is exposed to a hang that reads as a scenario result. | UP:26-28, UP:160-161 vs DESIGN.md:787-794 | **HIGH** |
| D-e | Conflicting first hypothesis for "the Editor stopped answering": Safe Mode (§3.3) vs `blocked_by_dialog` (UP:162-165). `editor_status` is a better non-blocking first probe than either. | UP:162-165 vs DESIGN.md:298, :306 | MEDIUM |
| D-f | `eval`/`eval_file` are headed **(Runtime)** in UP while §3.2 gates them as live-Editor. Unresolved — UP:125/UP:135 share a duplicate `## 5.` number, so the label is unreliable. Needs a live probe, not a doc decision. | UP:125, UP:135, UP:168-169 vs DESIGN.md:249, :256, :259 | MEDIUM (open) |
| D-g | Trigger collision: `unity-pipeline` is a capability-shaped description competing in 100% of LIVE natural-trigger runs; HIGH against `unity-script-change-gate` and `unity-live-edit-verification`. `COMPETITOR_FIRED` is mandatory on every rep. | Step 3 table | **HIGH** |
| D-h | `unity-cli-contract`'s kept exit-code rows must be re-tested against UP:53-61 in conformance check 7, not only against SK/IA. | UP:53-61 vs DESIGN.md:115, :128 | LOW |
| D-i | **Not a `unity-pipeline` finding** — `/tmp/unity-ops-snapshot.sh` writes no `whitelist` / `sanctioned_mutations` keys, so every re-snapshot silently destroys them. Hit during this task; restored by hand. See `testbed-snapshot.md`. | `/tmp/unity-ops-snapshot.sh:49-61` | **HIGH** |
