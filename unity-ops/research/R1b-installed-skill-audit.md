# R1b — Installed `unity-cli` skill audit (READ-ONLY)

Re-derives R1/DESIGN's claims against the skill actually loaded by agents: `~/.claude/skills/unity-cli/` (installed copy), diffed against `Unity-Technologies/skills@main` fetched via `gh api`. No mutating CLI command was executed. Local file abbreviations below: SK=`SKILL.md`, IA=`references/integration-advanced.md`, BRT=`references/build-run-test.md`, PT=`references/projects-templates.md`, EI=`references/editors-install.md`, DM=`references/diagnostics-maintenance.md`, CH=`references/config-hub.md`, CL=`references/collaboration.md`, ALC=`references/auth-license-cloud.md`, CHANGELOG=`CHANGELOG.md`, SEC=`SECURITY.md`. All installed-copy line numbers are from the file as it exists on disk today (no header offset).


> **Errata — 2026-09-14 (design revision 3).** Two rows below draw a wrong inference from a true fact, and three
> `BRT:414` anchors do not resolve. Corrected inline where they appear, and stated once here:
>
> - **`references/version-control.md` does not exist in the installed tree — true.** The conclusion drawn from it,
>   that the installed copy documents no `vcs` content at all (rows at `| references/version-control.md |`,
>   `| vcs |` in §B's coverage table, §E G8, and §H's "most consequential correction"), is **wrong**.
>   `unity vcs uvcs locks` (SK:257,280; PT:175-176), `unity vcs uvcs changesets` (SK:263; PT:179-180) and
>   `unity vcs uvcs review list|comments|reply|resolve` (PT:204-220) are documented **inline in `SKILL.md` and
>   `projects-templates.md`**. What is genuinely absent is the wider verb family and, for the G8 argument
>   specifically, **`vcs doctor`** — so G8's residual is real but narrower than this file says.
> - **`unity plugin install plastic` is documented** at SK:286 and PT:259. Absent: `plugin changelog`.
> - **`BRT:414` does not resolve** — `references/build-run-test.md` is **349 lines**. Every occurrence is annotated.
>
> Source: round-2 re-review `FIX_LIST` items R2-9 and R2-15, `.claude/plans/unity-ops-review-2026-09-14.md`.

---

## A. Inventory + version

| File | Installed line count | Notes |
|---|---|---|
| `SKILL.md` | 441 | |
| `CHANGELOG.md` | 242 | |
| `SECURITY.md` | 34 | |
| `references/auth-license-cloud.md` | 164 | |
| `references/build-run-test.md` | 349 | |
| `references/collaboration.md` | 477 | byte-identical to GitHub@main |
| `references/config-hub.md` | 103 | |
| `references/diagnostics-maintenance.md` | 326 | |
| `references/editors-install.md` | 327 | |
| `references/integration-advanced.md` | 516 | |
| `references/projects-templates.md` | 670 | byte-identical to GitHub@main |
| `references/version-control.md` | **does not exist** | confirmed via `ls`; GitHub@main has one at 499 lines |

**Version line:** SK:439 — *"The CLI is currently in **beta** (latest: `1.0.0-beta.8`)."* GitHub@main SK:443 says `1.0.0-beta.9`.

**CHANGELOG top entries:**

| | Installed | GitHub@main |
|---|---|---|
| Top heading | `## CLI 1.0.0-beta.8 (2026-09-01)` at CHANGELOG:13 | `## CLI 1.0.0-beta.9 (2026-09-08)` at CHANGELOG:13, pushing beta.8 to CHANGELOG:44 |
| Content | beta.8 entry only (a hotfix respin of withdrawn beta.7) | beta.9 entry (new) + beta.8 entry, unchanged |

The installed skill docs are pinned to the CLI version they were captured at (**beta.8**) — the same version R1 found the installed CLI **binary** to be. GitHub@main has moved one release ahead of both. This is the core correction to the plan review's premise: R1's "GitHub skill runs ahead of the installed CLI" framing is about the binary; the *installed skill docs* are not ahead of anything — they are simply older than GitHub@main by one CLI release, and several "Unity's skill already covers X" claims in DESIGN.md/R1 §B were verified against GitHub@main, not this file.

`SECURITY.md` also carries a GitHub-only addition — "Reading an automated scanner's verdict on this skill" (gh-SECURITY.md:15-23, absent locally) — not relevant to the six skills' content but confirms the docs pair (SKILL.md + SECURITY.md + CHANGELOG.md) drifted together, not just the references.

---

## B. GitHub vs installed diff

**Whole-file diff result:** `projects-templates.md` and `collaboration.md` are byte-identical. Every other file has GitHub@main strictly *ahead* — every diff hunk found is GitHub adding content; zero hunks found where the installed copy has content GitHub@main lacks. `version-control.md` doesn't exist locally at all.

| File | GitHub-only additions (absent locally) |
|---|---|
| `SKILL.md` | Sandboxed-agent callout (gh:38-39); `--color`/`--no-color` flag rows (gh:81-82); `auth consumers`/`auth revoke` in command index (gh:154); `config get/set/list/unset` in command index (gh:157); `version`, `ci init` in command index (gh:159); `skill show`, `plugin` family, `vcs` **row entirely** in command index (gh:160,163-165); expanded "rule out two false negatives" (sandbox) paragraph (gh:189-194); reworded UVCS day-to-day section naming `review` (gh:262-291); telemetry-ping sentence + beta.9 version bump (gh:442-443) |
| `CHANGELOG.md` | Entire beta.9 section (gh:13-43) |
| `references/integration-advanced.md` | `skill show` section (gh:127-147); entire "Plugin" section incl. `plugin upgrade`/`plugin changelog` (gh:149-196); entire "Sandboxed agent tooling can hide a running Editor" section (gh:409-458) |
| `references/auth-license-cloud.md` | "Consumers — see who's used your sign-in" section, `auth consumers`/`auth revoke` (gh:74-93) |
| `references/build-run-test.md` | Entire `--affected`/`--affected-compare`/`--since` subsection for `unity test` (gh:267-287) |
| `references/config-hub.md` | `config get/set/list/unset` section (gh:65-95) |
| `references/diagnostics-maintenance.md` | `doctor`'s "Third-party components" paragraph (gh:48); entire "CI init" section incl. `unity ci init`, `--shards` (gh:50-101); "Version — machine-readable version object" / `unity version` subcommand (gh:160-178); always-on `cli telemetry` ping paragraph (gh:264-265); self-installed-vs-Homebrew PATH-conflict warning (gh:379-380) |
| `references/editors-install.md` | `--child-modules`/`--no-child-modules` primary spelling (old `--cm`/`--no-cm` still work) (gh:217-326 assorted); `--list-modules` spelling (`--list-components` kept as hidden alias) (gh:235-237); `Aliases` column rename from `downloaderName` (gh:281) |
| `references/version-control.md` | **Entire file absent locally** — full `vcs` command family (`setup/status/sync/switch/doctor/providers/merge-setup/conflicts/explain/resolve/diff/blame/summarize/affected/hooks`, `vcs git`, `vcs uvcs`) |
| `references/projects-templates.md` | none — identical |
| `references/collaboration.md` | none — identical |
| `SECURITY.md` | "Reading an automated scanner's verdict on this skill" section (gh:15-23) |

No case found of the installed copy documenting something GitHub@main has since removed.

### Token-by-token presence check in the INSTALLED copy

| Token | Present locally? | Anchor |
|---|---|---|
| `--affected` | **No** | absent from BRT entirely (BRT:266 options line has no `--affected`); present GitHub-only at gh-BRT:267-287 |
| `--affected-compare` | **No** | same as above |
| `--since` | **No** | same as above |
| `install --list-modules` | **No** — only `--list-components` exists | EI:236 (`--list-components`); GitHub adds `--list-modules` as primary at gh-EI:236 |
| `plugin changelog` | **No** — entire `plugin` command family absent from IA | closest: IA:189 lists `pipeline`, no `plugin` heading anywhere in IA |
| `unity version` (subcommand) | **No** | bare `--version` flag exists (SK, "which unity && unity --version"); the structured `unity version` subcommand section is GitHub-only at gh-DM:160-178 |
| `vcs` | **No** — no `version-control.md`, no `vcs` row in SK's command index | closest: SK:159-160 command index has no `vcs` row at all |
| `collaboration` | **Yes** | CL (identical to GitHub@main), referenced at SK:161 |
| `--detach` | **No** — not in body text of either copy | only CHANGELOG:84 historical note ("intentionally not documented... shipped in beta.4, documented above" — that claim does not hold; grepped IA/SK, no dedicated content) |
| `job status\|wait\|cancel` | **No** — not in body text of either copy | IA:11 names `unity job` once as a resolver participant; no subcommand documentation anywhere |
| `ci init` | **No** | GitHub-only, gh-DM:50-101 |
| `doctor --ci` | **Yes** | DM:55,58,61 |
| `STATUS_NO_INSTANCES` | **Yes** | IA:337 |
| `AMBIGUOUS_EDITOR` | **Yes** | SK:30; IA:21,44 |
| `instancesInSafeMode` | **Yes** | IA:360,365 |
| `safeMode.detected` | **Yes** | IA:361,365 |
| `recompile` | **Yes** — but only inside the `[CliCommand]`-authoring section | IA:459-460 |
| `recompile_status` | **Yes** — same narrow context | IA:460 |
| `find_gameobjects` | **Yes** | IA:295 |
| `get_scene_hierarchy` | **Yes** | IA:296 |
| `save_scene` | **Yes** | IA:300; SK:174 |
| `save_all` | **Yes** | IA:300 |
| `attach_script` | **Yes** | IA:301 (chain entry only) |
| `create_script` | **Yes** | IA:301 (chain entry only) |
| `add_component` | **Yes** | IA:298 |
| `set_transform` | **Yes** | IA:297 |
| `create_gameobject` | **Yes** | IA:294; SK:173 |
| `editor_play` | **Yes** — example only, not in the built-in table | SK:17,27; IA:229,237,242 |
| `screenshot` | **Yes** | IA:233-234,251 |
| `eval` | **Yes** — optional/package-provided, explicitly not guaranteed | SK:18-19; IA:133,140,159,175,305-307,461 |
| `eval_file` | **Yes** — same caveat | IA:305,307,461 |
| `undo` (as an Editor command/primitive) | **No** — zero hits in any local or GitHub file | n/a — absent from both copies, not just the installed one |
| `read-back` / `read back` | **No** — zero hits, either copy | n/a — this is `unity-ops`'s own coinage |
| `exits without saving` | **No** — zero hits, either copy | see §H — this text does not exist in Unity's skill at all, local or GitHub |
| `projects clean` | **Yes** | PT:312-327 |
| `projects clean --force` | **No** — `clean` takes `-y/--yes`, not `--force` | PT:327 shows `--yes`; no `--force` flag documented on `clean` |
| `editors prune` | **Yes** | EI:128-146 |
| `--allow-install` | **Yes** | BRT:19,117,266,306; SK:367,383,392,405 |
| `pkill` | **Yes** — as a warned-against anti-pattern | IA:419 (`pkill -f Unity`) |
| `UNITY_NO_CONSENT_PROMPT` | **Yes** | SK:115; DM:174 |
| `UNITY_QUIET` | **Yes** | SK:100; behavior detailed at BRT:335 (suppresses build stall heartbeat in human mode) |
| `-logFile` | **Yes** | BRT:16,35,345; SK:393; IA:155,371; PT:31,51 |
| `error CS` | **Yes** | IA:383,388,398 |

---

## C. Restatement audit per proposed skill

Counts (Iron Law + Rationalization + Guardrails + Evidence + Default-env/flags rows, one classification per row):

| Skill | Rows | RESTATED | ADDITIVE | CONTRADICTS |
|---|---|---|---|---|
| `unity-surface-preflight` | 15 | 8 | 7 | 0 |
| `unity-live-edit-verification` | 17 | 3 | 14 | 0 |
| `unity-script-change-gate` | 15 | 8 | 7 | 0 |
| `unity-destructive-gate` | 20 | 6 | 14 | 0 |
| `unity-batch-hygiene` | 18 | 11 | 7 | 0 |
| `unity-cli-contract` | 17 | 10 | 7 | 0 |
| **Total** | **102** | **46** | **56** | **0** |

No row across any of the six skills asserts something the installed copy actively contradicts. The ADDITIVE share is larger than DESIGN's own framing implies (DESIGN treats most of this territory as "Unity already covers it, don't restate" for the *cut* candidates in §2, but the six *shipped* skills' actual rationalization/guardrail/evidence content is, row for row, majority-new relative to the installed docs — see per-skill tables below).

### 3.1 `unity-surface-preflight`

| Row | Class | Anchor |
|---|---|---|
| Iron Law ("both false negatives ruled out") | ADDITIVE | Safe-Mode half is RESTATED at SK:184-186; sandbox half has no installed anchor (closest: SK:184, which is silent on sandboxes) |
| Rational: "status says no instances → closed" (sandbox false negative) | ADDITIVE | no installed anchor — closest IA has no Sandboxed section at all |
| Rational: "timed out → wedged, restart it" (Safe Mode) | RESTATED | SK:186; IA:339-425 |
| Rational: "I'll just edit SampleScene.unity" (fileIDs/reimport/wrong scene) | RESTATED | SK:179-183 |
| Rational: "only one Editor could be open" (resolver/cwd) | RESTATED | IA:9-21; SK:24-30 |
| Rational: "fresh headless Editor gets me the same place" (forbidden silent substitution) | ADDITIVE | only exists in the absent Sandboxed section (gh-IA:409-458) |
| Guardrail: gate `Edit`/`Write` on `*.unity/*.prefab/*.asset` | RESTATED | underlying rule at SK:179-184 (the glob-enforced *gate* is unity-ops's own mechanism, but the rule it enforces is stated) |
| Guardrail: `command`/`list` w/o `--project-path` at ≥2 instances | RESTATED | SK:24-30 |
| Guardrail: "no Editor" conclusion needs Safe-Mode check **and** sandbox question | ADDITIVE | Safe-Mode half RESTATED (SK:186); sandbox half absent |
| Guardrail: `unity pipeline install` never auto-run, always ask | ADDITIVE | SK:26 presents it as a normal one-time setup step, no caution stated |
| Evidence: "live Editor reachable" ⇐ `status --format json` + `ready` | RESTATED | SK:17; IA:326-337 |
| Evidence: "no live Editor" ⇐ status empty + safe-mode 0 + human sandbox answer | ADDITIVE | sandbox leg absent |
| Evidence: "in Safe Mode" ⇐ `pipeline list` json `safeMode.detected` | RESTATED | IA:360-361 |
| Evidence: "right project" ⇐ pwd + `--project-path` + reading `ProjectVersion.txt` | ADDITIVE | not stated as an evidence requirement anywhere; closest IA:9-21 |
| Default env/flags (`UNITY_NO_BANNER`/`NON_INTERACTIVE`/`NO_PAGER`/`FORMAT`/`NO_CONSENT_PROMPT`/`NO_UPDATE_CHECK`) | RESTATED | SK:90-119 |

### 3.2 `unity-live-edit-verification`

| Row | Class | Anchor |
|---|---|---|
| Iron Law (read-back + save before "done") | ADDITIVE | R1 §G1 gap confirmed still open locally; closest IA:288-311 (catalog only, no verification framing) |
| Rational: "`success:true` so it exists" | ADDITIVE | envelope/`success` mechanics RESTATED at SK:434; the "success ≠ verified, go read back" inference is not stated |
| Rational: "I'll save at the end" (no end; close/domain-reload drop state) | ADDITIVE | `unity close` and its save semantics are **entirely undocumented** locally (see §H) |
| Rational: "re-reading costs a round trip" (200-600ms) | RESTATED | IA:132-138 |
| Rational: "I'll just undo it" (no undo primitive) | ADDITIVE | skill is silent, not affirmative — no `undo` entry anywhere in the catalog (IA:288-301) to point at |
| Rational: "it's one eval, can't do much" (full privilege, only 30s timeout bound) | RESTATED | IA:241,305-307; SEC (SEC_POWER_CAP, local:1-34) |
| Guardrail: gate mutating commands, warn if next call isn't a read-back | ADDITIVE | not stated; command names RESTATED (IA:294-301), sequencing rule invented |
| Guardrail: bound `eval`/`eval_file` (return value, checkpoint, one mutation, explicit timeout) | ADDITIVE | `--timeout` flag RESTATED (IA:241); "one mutation/checkpoint" discipline invented |
| Guardrail: batch of >1 mutation needs per-item read-back | ADDITIVE | not stated |
| Guardrail: claiming done without `save_scene`/`save_all` | ADDITIVE | commands RESTATED to exist (IA:300); requirement-framing invented |
| Guardrail: `eval` that writes files/shells out → ask | ADDITIVE | not stated as a distinct case |
| Evidence: GameObject exists ⇐ post-mutation `find_gameobjects`/`get_scene_hierarchy` | ADDITIVE | commands RESTATED to exist; "requires" framing invented |
| Evidence: transform at X ⇐ read-back | ADDITIVE | not stated |
| Evidence: change saved ⇐ `save_scene` success + post-save read-back | ADDITIVE | `save_scene` RESTATED to exist (IA:300); post-save read-back requirement invented |
| Evidence: all N objects created ⇐ N read-backs | ADDITIVE | not stated |
| Evidence: eval did what intended ⇐ returned value read | ADDITIVE | pattern shown by example (SK:18-19) but not framed as a requirement |
| Default env/flags (explicit `--timeout` always; `--project-path` explicit) | RESTATED | IA:241 (30s default); SK:24-30 |

### 3.3 `unity-script-change-gate`

| Row | Class | Anchor |
|---|---|---|
| Iron Law (no claim until completed recompile) | ADDITIVE | `recompile`/`recompile_status` only documented inside `[CliCommand]`-authoring context (IA:459-461), never generalized — matches R1 §G2, confirmed still true locally |
| Rational: "file written, syntax fine" (Editor hasn't seen it) | ADDITIVE | `attach_script` RESTATED to exist (IA:301); failure/silent-attach behavior not documented |
| Rational: "Unity picks it up on focus" (drive recompile, poll recompile_status) | RESTATED | IA:459-461 |
| Rational: "`unity command` stopped responding → crashed" (Safe Mode) | RESTATED | IA:339-351 |
| Rational: "I'll dump Editor.log and read it" (narrowest log, grep, untrusted data) | RESTATED | IA:365-401 |
| Rational: "`unity logs` will show compile errors" (reads CLI log, not Editor.log) | RESTATED | DM:28-30 |
| Guardrail: `.cs` write → `attach_script`/`add_component` without recompile+completed between | ADDITIVE | pieces RESTATED individually; sequencing gate invented |
| Guardrail: claiming "it compiles" requires `recompile_status` quoted | ADDITIVE | not stated as a claim-requirement |
| Guardrail: `unity command` timing out within 1 min of `.cs` write → force Safe-Mode check | ADDITIVE | general "diagnose Safe Mode first" RESTATED (IA:339-345); the 1-minute trigger window is invented |
| Guardrail: restarting to "clear" a compile error → fix source first, restart by PID, never `pkill -f Unity` | RESTATED | IA:403-419 |
| Evidence: "it compiles" ⇐ `recompile_status` completed, polled this session | RESTATED | IA:459-461 |
| Evidence: "component attached" ⇐ `attach_script` + read-back | ADDITIVE | `attach_script` RESTATED to exist; read-back requirement invented |
| Evidence: "not in Safe Mode" ⇐ `pipeline list` json `instancesInSafeMode:0` | RESTATED | IA:360-365 |
| Evidence: "compile errors are X/Y" ⇐ grep `error CS` from narrowest log, this session | RESTATED | IA:365-398 |
| Default env/flags (`recompile --timeout 180`) | ADDITIVE | 30s default on `command` RESTATED (IA:241); the 180s recommendation is invented |

### 3.4 `unity-destructive-gate`

| Row | Class | Anchor |
|---|---|---|
| Iron Law (never discard without saying/confirming/naming recovery) | ADDITIVE | no unifying statement; closest scattered confirmations at PT:333, EI:146 |
| Rational: "user told me to close it" (`close` "exits without saving") | ADDITIVE | **`unity close` is undocumented anywhere in the installed skill** — no command-index row, no reference-file section (see §H) |
| Rational: "`--force` just makes it faster" (SIGTERM→SIGKILL, skips graceful quit) | ADDITIVE | this describes `close --force`; `close` is wholly absent locally. A different SIGTERM→SIGKILL pattern exists for `run`/`build`/`test` timeouts (BRT:39) but is not the same command |
| Rational: "`pkill -f Unity` is reliable" (takes down every Editor; use PID) | RESTATED | IA:415-419 |
| Rational: "`projects clean` is safe, CLI blocks it if open" (warns and proceeds anyway) | RESTATED | PT:332 |
| Rational: "`--yes` is what you use in automation" (required non-interactively because it removes a check) | RESTATED | EI:146,189; PT:333; ALC:114 (mechanism stated repeatedly; "defeats the guardrail" editorializing is unity-ops's own framing) |
| Rational: "`--allow-install` just handles a missing editor" (multi-GB, no size/consent prompt) | ADDITIVE | flag's bare function RESTATED (BRT:306: "Install the project's editor version if missing"); size/no-prompt warning not stated |
| Rational: "I'll `self-update` first" (replaces the binary mid-session dependents rely on) | ADDITIVE | `self-update` documented (DM:270-303) with no mid-session risk warning |
| Guardrail: `unity close [--force]` — enumerate unsaved edits, require save/discard | ADDITIVE | `close` undocumented locally |
| Guardrail: `unity projects clean [--yes]` — require editors closed first | ADDITIVE | underlying refuse/warn-and-proceed behavior RESTATED (PT:332); "require closed first" as an enforced step is invented |
| Guardrail: `unity editors prune --remove [--yes]` — require dry report read first | ADDITIVE | report-only default and `--yes` requirement RESTATED (EI:128-146); "require read first" workflow invented |
| Guardrail: `unity uninstall`/`self-uninstall`/`self-update` — never mid-session | ADDITIVE | commands documented (DM:270-323), no mid-session caution |
| Guardrail: `--allow-install` — warn + state size + ask | ADDITIVE | flag documented, no size-warning framing |
| Guardrail: `--yes`/`--force` added to anything → warn, name confirmation skipped | ADDITIVE | no such meta-guardrail stated |
| Guardrail: `pkill -f Unity`/`killall Unity` → rewrite to `kill <pid>` | RESTATED | IA:419 |
| Evidence: "nothing unsaved lost by closing" ⇐ `save_scene`/`save_all` + read-back | ADDITIVE | `close`'s save semantics undocumented at all |
| Evidence: "no Editor has project open" ⇐ `status --format json` + sandbox caveat | ADDITIVE | status check RESTATED; sandbox caveat absent |
| Evidence: "pruning removes only unused editors" ⇐ report-only output read | RESTATED | EI:128-146 |
| Evidence: "editor killed cleanly" ⇐ PID from `pipeline list` + kill result | RESTATED | IA:415-419 |
| Default env/flags (no blanket `--yes`; `NON_INTERACTIVE` stays, not a `--yes` license) | ADDITIVE | policy interpretation, not stated in skill |

### 3.5 `unity-batch-hygiene`

| Row | Class | Anchor |
|---|---|---|
| Output-contract: always backgrounded | ADDITIVE | Jeremy's own standing instruction, not a Unity skill statement |
| Output-contract: explicit `--timeout` because no default | RESTATED | BRT:310 ("Disabled by default"); `UNITY_RUN_TIMEOUT`/`UNITY_TEST_TIMEOUT`/`UNITY_BUILD_TIMEOUT` all in SK:108-109 env table |
| Output-contract: machine format + `--no-tail` on build | RESTATED | BRT:276,305 |
| Output-contract: named artifact path (`--output`/`--report-format`, absolute build log) | RESTATED | BRT test/build option tables (BRT:266,300) |
| Output-contract: exit-code reading (0/8/6/130/143) | RESTATED | SK:127-146; BRT:29,246,333 (**errata: revision 3** — `BRT:414` does not exist; `build-run-test.md` is 349 lines. The exit-code content is at BRT:29 (exit 6 on reserved flags), BRT:246 (gate on the exit code) and BRT:333 (130/143 interrupt codes); `SK:127-146` was always the primary anchor and is in range.) |
| Output-contract: one-line report (verdict, artifact path, failure count) | ADDITIVE | not a stated requirement |
| Guardrail: no `--timeout`/env → warn + inject a default | ADDITIVE | "disabled by default" fact RESTATED; auto-injection behavior invented |
| Guardrail: foreground launch → warn + move to background | ADDITIVE | not stated |
| Guardrail: non-zero exit treated as one failure class → print 0/8/6/130/143 reading | RESTATED | SK:127-146; BRT:29,246,333 (**errata: revision 3** — `BRT:414` does not exist; `build-run-test.md` is 349 lines. The exit-code content is at BRT:29 (exit 6 on reserved flags), BRT:246 (gate on the exit code) and BRT:333 (130/143 interrupt codes); `SK:127-146` was always the primary anchor and is in range.) |
| Guardrail: Android keystore flags on command line → argv leak even from env var | RESTATED | BRT:327 |
| Guardrail: reserved batch flags after `--` → strip, CLI rejects exit 6 | RESTATED | BRT:24-33 |
| Guardrail: `--affected`/`--affected-compare`/`--shard`/`--rerun-failed` mutually exclusive | ADDITIVE | the entire `--affected` family (and its exclusivity text) is absent locally — not just "doesn't exist on beta.8" as a fact, but the guardrail's own source text doesn't exist in this copy at all |
| Evidence: "tests pass" ⇐ fresh json output, exit 0, full suite, counts quoted | ADDITIVE | exit 0 = success RESTATED generally; the specific evidence bundle is invented |
| Evidence: "tests fail, not infra" ⇐ exit 8 or `errors[0].code==TESTS_FAILED` | RESTATED | SK:137; BRT:141 (**errata: revision 3** — the co-anchor `414` does not exist; the file is 349 lines) |
| Evidence: "infra failure" ⇐ exit 6/4/3 with `errors[0].code` | RESTATED | same citations |
| Evidence: "builds cleanly" ⇐ fresh build exit 0 + absolute log path + `data.provenance` | RESTATED | BRT:331 |
| Evidence: "build is at `<path>`" ⇐ `ls`/stat this session | ADDITIVE | not stated |
| Default env/flags (`UNITY_QUIET` deliberately unset — silences stall heartbeat) | RESTATED | BRT:335 (exact match); the specific numeric floors 900/3600/600 are unity-ops's own choice |

### 3.6 `unity-cli-contract`

| Row | Class | Anchor |
|---|---|---|
| Output-contract: dependency check `skill install --list` | RESTATED | IA:93 |
| Output-contract: CLI presence `command -v unity && unity --version` | RESTATED | SK "which unity && unity --version" (local:42-44) |
| Output-contract: parse `beta.N`, record in-session | ADDITIVE | not stated as a required practice |
| Output-contract: probe parent `--help`, never trust a nested subcommand's own `--help` | ADDITIVE | this is a live-CLI-binary defect R1 discovered by testing, not documentable content in a skill; no anchor in either copy |
| Output-contract: export env block | RESTATED | SK:90-119 |
| Output-contract: parse stdout, branch on `success`, `errors[0].code` stable | RESTATED | SK:434 |
| "Known beta.9-only surface" table (4 rows) | ADDITIVE | this is R1's own derived table, not skill-stated text — and it now under-counts: the installed copy also lacks `--color`, `auth consumers/revoke`, `config get/set/list/unset`, `skill show`, the whole `plugin` and `vcs` families, and the sandboxed-agent section (see §B) |
| Guardrail: beta.9-only flag without a probe → warn, probe first | ADDITIVE | not stated |
| Guardrail: nested-subcommand `--help` fallthrough → re-probe parent's `Commands:` list | ADDITIVE | CLI defect, not documented in either copy's body text |
| Guardrail: parsing stderr / empty-stdout-as-failure → warn, point at `success`/`errors[0].code` | RESTATED | SK:434 |
| Guardrail: running without envelope on a TTY → warn (pager/`projects list` risk) | RESTATED | SK:86-90 (verbatim, identical in both copies) |
| Guardrail: proceeding when `unity-cli` not installed → hard stop | ADDITIVE | self-referential dependency policy, not stated by the skill about itself |
| Evidence: "CLI supports flag X" ⇐ `--help` output this session, not the skill's own docs | ADDITIVE | meta-rule about the skill's own reliability; not something the skill states about itself |
| Evidence: "unity-cli is installed" ⇐ `skill install --list` this session | RESTATED | IA:93 |
| Evidence: "command failed because Y" ⇐ `errors[0].code` | RESTATED | SK:434 |
| Evidence: "CLI is version N" ⇐ `unity --version` this session, not CHANGELOG | RESTATED | bare `--version` flag exists locally; the "don't trust CHANGELOG" epistemic framing is additive nuance but the underlying command is restated |
| Default env/flags (`UNITY_QUIET` available, not set by default) | RESTATED | SK:100; BRT:335 |

---

## D. "Considered and cut" re-verification (DESIGN.md §2)

| Cut candidate | DESIGN's stated reason | Installed-copy verdict |
|---|---|---|
| `unity-safe-mode-recovery` | "Unity's skill already covers it — R1 §B (full 6-step playbook...)" | **Covered.** IA:339-425, full loop incl. `instancesInSafeMode`, per-OS log paths, kill-by-PID warning |
| `unity-sandbox-false-negative` | "Unity's skill already covers it — R1 §B (`integration-advanced.md#sandboxed-agent-tooling-can-hide-a-running-editor`...)" | **Not covered locally — reconsider.** Confirmed zero hits for sandbox-hiding-Editor content anywhere in the installed copy. R1's claim was verified against GitHub@main only. Until the local skill is refreshed, this candidate cannot be "just a branch of preflight" — the underlying content it would cite doesn't exist yet in what agents load |
| `unity-editor-targeting` | "R1 §B (resolver precedence, `AMBIGUOUS_EDITOR`, `data.candidates`)" | **Covered.** IA:9-48 |
| `unity-command-query` | "R1 §B (`--query/--tag/...` table, `--group_by` underscore trap)" | **Covered.** IA:245-267 |
| `unity-clicommand-authoring` | "R1 §B (full C# example, `MainThreadRequired`/`RuntimeOnly` semantics)" | **Covered.** IA:426-461 |
| `unity-shell-ndjson` | "R1 §B (framed request/response protocol, session context, secret masking)" | **Covered.** IA:465-516 (ndjson protocol at 502-516; secret-masking at IA:481) |
| `unity-build-flags`/`unity-android-signing` | "R1 §B (every flag tabulated, keystore-scrubbing-on-exit documented)" | **Covered.** BRT:290-335 |
| `unity-ci-scaffold` | "Out of scope by decision 5, and Unity's skill already covers it — R1 §B (`unity ci init`, `doctor --ci`, sharded-matrix recipe)" | **Partially not covered — reconsider the coverage claim (the scope decision itself stands independently).** `doctor --ci` **is** covered (DM:55-61); `unity ci init` and the whole sharded-matrix generator are GitHub-only (gh-DM:50-101), entirely absent locally |
| `unity-package-management` | scope note (separate skill entirely) | N/A — not part of `unity-cli`, unaffected by this audit |
| `unity-mcp-setup` | "Out of scope by decision 2" | **Covered.** IA:50-86 (`mcp`/`mcp configure`, identical to GitHub@main) |
| `unity-pipeline-bootstrap` | "YAGNI as its own skill" | N/A — design decision, not a doc-coverage claim |
| `unity-findings-to-issues` | "Already binding globally via `~/.claude/CLAUDE.md`" | N/A — not Unity CLI content |
| `unity-project-health` | "`unity doctor --format json` already does it" | **Covered.** DM:41 |

---

## E. Gap re-verification (R1 §G1–G11)

| Gap | Still a gap against the installed copy? | Closest local content |
|---|---|---|
| G1 — Verification-after-live-edit loop | **Yes, still open.** No dry-run/undo-diff/assert primitive; catalog only | IA:288-311 (command table, no verification framing) |
| G2 — Waiting for domain reload/compile after a live script change | **Yes, still open.** `recompile`/`recompile_status` remain documented only inside the `[CliCommand]`-authoring walkthrough, never generalized | IA:459-461 |
| G3 — Reading Editor.log / compile errors outside Safe Mode | **Yes, still open.** The full log-reading recipe stays framed entirely as Safe Mode recovery; `unity logs` explicitly reads the CLI's own log, not `Editor.log` | IA:339-425 (Safe Mode frame only); DM:28-30 (`unity logs` disclaimer) |
| G4 — Play-mode test loop / interactive play-mode iteration | **Yes, still open.** `editor_play` remains a bare example command with no enter→poll→assert→exit pattern | SK:17,27; IA:229-242 (one-line examples only, not in the built-in table) |
| G5 — Screenshot / visual verification workflow | **Yes, still open.** One example line, no baseline/comparison/failure guidance | IA:233-234,251 |
| G6 — Undo/revert strategy for live-Editor mutations | **Yes, still open.** No `undo` command anywhere in the catalog or elsewhere, locally or on GitHub@main | IA:288-301 (catalog, no undo entry) |
| G7 — `--detach`/`job` lifecycle documentation | **Yes, still open — and now confirmed open on GitHub@main too, not just locally.** Grepped every local and GitHub file for "detach"/"job status"/"job wait"/"job cancel": zero dedicated section in either copy, only IA:11's one-line resolver mention and a CHANGELOG historical note (CHANGELOG:84) whose claim ("documented above" once shipped in beta.4) does not hold under grep | IA:11 only |
| G8 — Git hygiene around `Library/` | **Worse than R1 characterized.** R1 said "`vcs doctor` already checks ignore rules prospectively; only after-the-fact recovery is missing." Locally, the entire `vcs` family (including `vcs doctor`) is absent (no `version-control.md`) — so even the *prospective* check R1 credited doesn't exist in this copy. The `.gitignore`-for-`Library/` bootstrap snippet does still exist | SK:299-315 (bootstrap `.gitignore` only) |
| G9 — Batch vs live decision framework | **Yes, still open.** Only the latency rationale is given, no decision framework | IA:132-138 |
| G10 — `unity-pipeline` project-local skill contents | **Unchanged — still unknown.** Nothing to verify differently; same "only materializes once mirrored into a real project" status | SK:34; IA:108 |
| G11 — Package management entirely out of CLI scope | **Unchanged — still true.** No package-management command anywhere in the installed copy | n/a (confirmed by absence) |

---

## F. Command-name catalog as documented locally (`references/integration-advanced.md`)

| `unity command <name>` | Line(s) | Status |
|---|---|---|
| `create_gameobject` | IA:294 | Built-in (Pipeline package scene/GameObject table, IA:286-288) |
| `find_gameobjects` | IA:295 | Built-in |
| `get_scene_hierarchy` | IA:296 | Built-in |
| `set_transform` | IA:297 | Built-in |
| `add_component` | IA:298 | Built-in |
| `rename_gameobject` / `delete_gameobject` | IA:299 | Built-in |
| `save_scene` / `save_all` | IA:300 | Built-in |
| `create_script` → `recompile` → `attach_script` | IA:301 | Built-in (chain) |
| `eval` / `eval_file` | IA:305-307 | Package-provided/optional — explicitly "availability depends on the Editor/package, discover it at runtime, don't assume" |
| `screenshot` | IA:233-234,251 | Built-in — "forwarded to the Editor's screenshot command, new in 0.1.0-beta.8"; shown as a `command` usage example, not in the "Available in production" table |
| `editor_play` | SK:17,27; IA:229,237,242 | Example only — "run one — e.g. enter Play mode"; not listed in the built-in table at all, not guaranteed |
| `spawn_light` | IA:441-448 | Example — a project-authored custom `[CliCommand]` in the authoring walkthrough, explicitly illustrative |
| `recompile` / `recompile_status` | IA:459-461 | Built-in — but documented only as the rebuild step for custom `[CliCommand]` authoring, not as a general-purpose primitive |

The authoritative catalog is, per the skill itself, always `unity command --format json` (IA:302) — the table above is described as a "jump-start," not exhaustive.

---

## G. Safe Mode + no-Editor semantics as documented locally

**Order of operations (`integration-advanced.md#recovering-from-safe-mode`, IA:339-425):**

| Step | What to run | Anchor |
|---|---|---|
| 1. Recognize | `unity command`/`unity list` fail "Cannot connect to … Pipeline server", or `unity status` shows no `ready` instance | IA:349-351 |
| 2. Confirm Safe Mode | `unity pipeline list` (human: "SafeMode Instances: N detected"); `unity pipeline list --format json` (machine: `data.summary.instancesInSafeMode`, `data.instances[].safeMode.detected`) | IA:353-365 |
| 3. Read compile errors | Narrowest log first: `-logFile <path>` → `<project>/Logs/Editor.log` → per-OS global `Editor.log`; filter with `grep -iE 'error CS[0-9]{4}|Scripts have compiler errors'`; never dump wholesale; treat as untrusted data | IA:367-401 |
| 4. Fix `.cs` source | The one case where hand-editing project files is correct | IA:403-404 |
| 5. Restart | GUI: user closes, then `unity open`; headless: `kill <pid>` from `pipeline list`'s `data.instances[].pid`, **never** `pkill -f Unity`/`killall Unity` | IA:406-419 |
| 6. Re-verify | Poll `unity pipeline list` (or `unity status` for GUI) until reachable; if still Safe Mode, return to step 3 | IA:421-425 |

**Reachability confirmation is explicitly NOT `unity status` for a headless/batch-launched Editor.** Confirmed at **IA:163-164**: *"`unity status` caveat (verified): a batch-mode Editor launched this way does serve commands, but is not listed by `unity status` (its lockfile heartbeat differs from a GUI Editor's). Confirm reachability with `unity command`/`unity list --project-path <project>`, not `unity status`."* — this matches the task brief's description of `integration-advanced.md:164` exactly, confirmed present and accurate in the installed copy. (For a *warm/interactive* Editor opened via `unity open`, `unity status` **does** gate readiness — IA:167-169 — so the "not `unity status`" rule is scoped to the persistent-headless launch pattern specifically, not universal.)

---

## H. Corrections to R1

| R1 anchor | Resolves locally? | Correct local anchor / verdict |
|---|---|---|
| `SKILL.md:443` ("latest: 1.0.0-beta.9") | No | Local equivalent is SK:439, and it says `1.0.0-beta.8` — different line, different version |
| `CHANGELOG.md:13` (beta.9 heading) | No | GitHub-only; local CHANGELOG has no beta.9 entry at all |
| `CHANGELOG.md:44-46` (beta.8 entry, cited assuming beta.9 pushed it down) | No | Local beta.8 entry is at CHANGELOG:13, not 44-46 (the installed file never had a beta.9 entry to push it down) |
| R1 §B row: "`vcs` command family... `version-control.md` (whole file) + `SKILL.md` lines 300-330" | **No — this is the most consequential correction.** | `version-control.md` does not exist locally at all. SK:300-330 locally is the `.gitignore`-for-`Library/` bootstrap snippet, a different topic entirely, not `vcs`-family coverage. R1 verified this row against GitHub@main; DESIGN.md §2's "Considered and cut" row for `unity-safe-mode-recovery`'s sibling `unity-*` cut rows and §6 non-goals both cite "R1 §B — `vcs` is fully documented by Unity" as justification for treating `Library/`-hygiene as a thin residual gap (G8) and cutting `vcs`-adjacent skill ideas. Locally, `vcs` is **not documented at all** |
| R1 §B row: "Sandboxed-agent false-negative... `integration-advanced.md#sandboxed-agent-tooling-can-hide-a-running-editor`" | **No** | GitHub-only (gh-IA:409-458); confirmed absent from the installed copy in full (§B, §D above) |
| R1 §D / §E1: `close <project> — "exits without saving"`, cited to `local unity close --help; SKILL.md command table line 240` | **No — `SKILL.md:240` does not resolve to anything about `close`.** | Local SK:240 is mid-example for `unity projects create` (git/UVCS flags). The `unity close` command is **not documented anywhere in the installed skill's body text** — not in the SK command-index table (which lists `projects (list/create/new/clone/open/link/require/upgrade/export/import/pin/size/clean/exec)` with no `close`), and not in any reference file. `"exits without saving"` returns zero hits across every local **and** GitHub@main file. R1's citation for this text was the **live CLI binary's own `--help`**, not the skill documentation — R1 §D's own methodology note confirms this ("local `unity close --help`"), but the parenthetical `SKILL.md:240` citation in §E1 conflates the two sources. This matters because DESIGN.md's `unity-destructive-gate` Iron Law and its highest-severity rationalization row are built on this exact quote (see §C above — every `close`-related row in that skill's tables is ADDITIVE, not RESTATED, as a direct result) |
| R1 §C: `recompile`/`recompile_status` at `integration-advanced.md:371,579-581` | Partially — line numbers are GitHub@main's | Local anchor is IA:459-461 (same content, different line numbers due to the `skill show`/`plugin` insertions earlier in GitHub's copy) |
| R1 §C: latency rationale at `integration-advanced.md:203-206` | Partially — GitHub@main line numbers | Local anchor is IA:132-138 (same content) |
| R1 §C: Safe Mode recovery loop at `integration-advanced.md:459-545` | Partially — GitHub@main line numbers | Local anchor is IA:339-425 (same content, verified verbatim-identical between the two copies for this section) |
| R1 §C: sandbox false negative at `integration-advanced.md:409-457` | **No** | GitHub-only; no local equivalent at any line |
| R1 §C: resolver precedence at `integration-advanced.md:9-48, 287` | **Yes, resolves as-is** | IA:9-48 is identical text at identical line numbers in both copies (this section sits before any GitHub-only insertion point) |
| R1 §A "beta.9-only" table (4 rows: `unity version`, `test --affected*`, `install --list-modules`, `plugin changelog`) | Accurate but now known to be an undercount | All 4 confirmed still absent locally (§B token table above); but the installed skill **also** lacks `--color`/`--no-color`, `auth consumers`/`revoke`, `config get/set/list/unset`, `skill show`, the entire `plugin` and `vcs` families, and the sandboxed-agent section — none of which R1 §A's table names, because R1 §A was scoped to CLI-binary-vs-GitHub-skill flag diffing, not installed-skill-doc-vs-GitHub-skill-doc diffing (the axis this audit covers) |
| R1 §H raw command inventory row `vcs \| Version control automation (git/UVCS) \| Medium` | Accurate for the **CLI binary** (R1 ran `unity vcs --help` live) | Not documented in the installed **skill**; the binary and the local docs disagree on `vcs`'s existence even though R1 didn't flag this because R1's binary probing and GitHub-skill reading were never cross-checked against the installed skill doc, which is this audit's contribution |

**Summary of the correction:** every place DESIGN.md or R1 wrote "Unity's skill already covers X" for `vcs`, the sandboxed-agent caveat, `ci init`, `plugin changelog`, `auth consumers/revoke`, `config get/set/list/unset`, `skill show`, or `--color`, the claim is **true of GitHub@main and false of the installed copy agents actually load**. The `unity close` "exits without saving" quote that anchors `unity-destructive-gate`'s Iron Law is not sourced from the skill at all (installed or GitHub) — it is live-CLI-`--help` text that R1 mis-cited to `SKILL.md:240`.
