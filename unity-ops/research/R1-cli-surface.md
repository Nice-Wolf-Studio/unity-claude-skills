# R1 — Unity CLI surface research (READ-ONLY)

Installed: `unity 1.0.0-beta.8` (macOS arm64, `~/.unity/bin/unity`). GitHub skill fetched from `Unity-Technologies/skills@main`. No mutating command was executed; only `--help`, `status`, `doctor`, `env`, `editors --json`, `pipeline list-versions`, `changelog`, `skill install --list`, `skill install claude-code --dry-run`.

---

## Errata — 2026-09-14 (added during design revision 3; the body below is otherwise unchanged)

This file remains authoritative for **binary** behaviour. Three claims in it have been corrected by later work and
must be read through these notes rather than at face value. `R1b-installed-skill-audit.md` supersedes R1 on every
question about the **installed skill docs**.

| # | Claim in this file | Correction | Source |
|---|---|---|---|
| E1 | §A second-order finding (line 31): nested `unity <parent> <child> --help` **"all silently fall through and print the root help"** — stated categorically. | **Observed intermittently, not always.** The same invocation printed root help once and correct subcommand help on three immediate re-runs, with and without env vars, piped and not, exit 0 throughout. The operative rule is unchanged and stronger: **root help printed is never evidence of absence — re-run, then probe the parent's `Commands:` list.** Every downstream document uses that wording; this file's categorical phrasing is the outlier. | Live re-probe, 2026-09-14; DESIGN.md §3.6, PLAN.md G3 |
| E2 | §B `vcs` row: the `vcs` family is described as documented only on GitHub@main / absent from the installed skill. | **Partly wrong.** `unity vcs uvcs locks` (SK:257,280; PT:175-176), `unity vcs uvcs changesets` (SK:263; PT:179-180) and `unity vcs uvcs review list\|comments\|reply\|resolve` (PT:204-220) **are** documented in the installed copy. What is absent is the wider verb family (`setup/status/sync/switch/doctor/providers/merge-setup/conflicts/explain/resolve/diff/blame/summarize/affected/hooks`, `vcs git`) and, load-bearingly for the `unity-library-hygiene` v2 candidate, **`vcs doctor`**. There is no `references/version-control.md` **file** in the installed tree — that much is true, and is what the wrong inference was drawn from. | Round-2 re-review R2-9; verified at SK:257,263,280,286 and PT:175-220,259 |
| E3 | §B `plugin` row: the `plugin` family is described as GitHub-only. | **Partly wrong.** `unity plugin install plastic` **is** documented in the installed copy at SK:286 and PT:259. Absent: `plugin changelog` and the rest of the family's verbs. | Round-2 re-review R2-9 |

---

## A. Version relation — GitHub skill is ONE beta AHEAD of the installed CLI

**Verdict: they do not match. The GitHub `unity-cli` skill documents `1.0.0-beta.9`; the installed CLI is `1.0.0-beta.8`.**

Evidence:
- `unity --version` → `1.0.0-beta.8` (local binary).
- GitHub `SKILL.md` Notes section: *"The CLI is currently in **beta** (latest: `1.0.0-beta.9`)"* — `SKILL.md:443`.
- GitHub `CHANGELOG.md:13` — `## CLI 1.0.0-beta.9 (2026-09-08)`, one entry ahead of `## CLI 1.0.0-beta.8 (2026-09-01)` at `CHANGELOG.md:44`. beta.9 shipped 2026-09-08; today is 2026-09-13, so the gap is real and current, not stale caching.
- `CHANGELOG.md:44-46` on beta.8 itself: *"Aligned to the CLI's `1.0.0-beta.8` release, which supersedes the withdrawn `1.0.0-beta.7`... reached the production beta channel and was pulled the same day."* — beta.8 (what Jeremy has) is itself a hotfix respin of a withdrawn release.

Flag-diff confirmation (local `--help` vs GitHub reference, all via allowed `--help` calls):

| Surface GitHub's beta.9-era skill documents | Present in local beta.8? | Evidence |
|---|---|---|
| `unity version` (structured version subcommand, `diagnostics-maintenance.md:160-169`) | **No** — `unity version --help` falls through to root help; not in the beta.8 command list | `unity --help` root command list (no `version` entry, only `-V/--version` flag) |
| `unity test --affected` / `--affected-compare` / `--since` (`build-run-test.md:266-286`) | **No** — absent from local `unity test --help` | `grep -i affected` on local `test --help` → no match |
| `unity install --list-modules` (doc says this is now primary, `--list-components` a "hidden alias", `editors-install.md:234-236`) | **No** — local `unity install --help` only exposes `--list-components`; no `--list-modules` spelling exists yet | local `install --help` output |
| `unity plugin` reference section (new in beta.9 per `CHANGELOG.md:20`, command family shipped since beta.7) | **Yes**, command family present (`list/install/remove/upgrade`, no `changelog` subcommand visible in local help despite doc claiming `plugin changelog <id>`) | local `unity plugin --help` — no `changelog` in the `Commands:` list |
| `unity vcs` reference section (new in beta.9 per `CHANGELOG.md:27`, family shipped since beta.7) | **Yes** — full verb set (`setup/status/sync/switch/doctor/providers/merge-setup/conflicts/explain/resolve/diff/blame/summarize/affected/hooks/git/uvcs`) matches local `unity vcs --help` | local `unity vcs --help` |
| `unity install --format json` prints the NDJSON result envelope on success (beta.8 changelog note, deferred to beta.9 doc pass) | Not independently verifiable read-only (would require running `install`) | — |
| `unity skill install <client> --local` mirrors the project's `com.unity.pipeline` skill (beta.8 changelog note) | **Yes**, confirmed present in beta.8 — `unity skill install --help` shows `--local` | local help + `SKILL.md:34`, `integration-advanced.md:108` |

**Practical implication for plugin design:** treat the GitHub skill as running *ahead* of whatever CLI version an agent actually has installed. A plugin built on top of it must NOT assume `unity version`, `test --affected`, or `install --list-modules` exist — probe with `--help` / a version guard before using beta.9+-only surface. The reverse direction (skill *behind* CLI) is the opposite risk and didn't manifest here, but the general lesson is: **pin the skill's assumptions to a probed CLI version, don't trust either side's changelog alone.**

Second-order finding: the CLI's own `unity <subcommand> --help` is unreliable for *nested* subcommands. `unity job status --help`, `unity job wait --help`, `unity job cancel --help`, and `unity projects exec --help` all silently fall through and print the **root** `unity --help` instead of their own usage — a CLI bug, not absence of the command (the parent `unity job --help` correctly lists `status`/`wait`/`cancel` as subcommands, and `unity projects --help` lists `exec`). A guardrail skill should not treat "root help printed" as "command doesn't exist."

---

## B. What Unity's skill already covers well — do not duplicate

| Topic | Where (file#heading) | One-line summary |
|---|---|---|
| Global flags (`--format`, `--json`, `--no-banner`, `--no-pager`, `--non-interactive`, `--quiet`, `--verbose`, `--color`) | `SKILL.md#Global flags` | Full table, every command supports these |
| Environment variables (`UNITY_*`) | `SKILL.md#Environment variables` | Full table incl. `UNITY_PROJECT_PATH`, `UNITY_RUN_TIMEOUT`, `UNITY_TEST_TIMEOUT`, service-account auth vars |
| Exit codes 0/1/2/3/4/6/8/130/143 | `SKILL.md#Exit codes` | Canonical table incl. test's exit-8 vs exit-6 distinction |
| Pager behavior (which commands page, `--no-pager`, `$PAGER`/`$UNITY_PAGER` resolution, broken-pager fallback) | `SKILL.md` lines 86-90 | Very detailed; two distinct pager mechanisms (`projects list` in-process vs external `less`) |
| Failure-shape contract (`success` field, `errors[0].code`, don't parse stderr, "known bug" caveat) | `SKILL.md` line 438 | Tells an agent exactly how to branch on failures |
| Editor targeting resolver order (`--runtime` > `--project-path` > cwd match) + `AMBIGUOUS_EDITOR` | `integration-advanced.md#Targeting one of several running Editors` | Exact precedence, exact JSON error shape (`data.candidates`) |
| Safe Mode detection & recovery loop | `integration-advanced.md#Recovering from Safe Mode (connection fails because of compile errors)` | Full 6-step playbook incl. `data.summary.instancesInSafeMode`, log paths per OS, "kill by PID not by name" warning |
| Sandboxed-agent false-negative on `unity status`/`command`/`list` | `integration-advanced.md#Sandboxed agent tooling can hide a running Editor` | Windows (ACL) vs macOS (loopback block) causes, explicit "never suggest disabling the sandbox" guidance |
| Authoring `[CliCommand]` custom tools | `integration-advanced.md#Authoring custom [CliCommand] tools` | Full C# example, `MainThreadRequired`/`RuntimeOnly` semantics, `recompile`/`recompile_status` rebuild loop |
| `command` query/filter flags (`--query/--tag/--detail/--group_by/--sort/--offset/--limit`) | `integration-advanced.md#Querying the command list` | Full table + the `--group_by` underscore trap + "flags become command params when a command name is given" trap |
| `pipeline install/upgrade` editor-selection semantics (auto-pick when 1 candidate, interactive/error when >1) | `integration-advanced.md` lines 259-287 | Covers non-interactive fallback behavior |
| `unity shell` REPL + `--protocol ndjson` machine mode | `integration-advanced.md#Shell — interactive REPL` / `#Machine/agent mode` | Framed request/response protocol spec, session context (`use project`, `set format`), secret-masking in shell history |
| Build flags incl. Android signing, `--no-tail`, provenance manifest, stall heartbeat, interrupt exit codes | `build-run-test.md#Build` | Comprehensive — every flag tabulated, keystore-scrubbing-on-exit documented |
| Test flags incl. `--shard`, `--retries`/flaky reporting, `--rerun-failed`, `--affected` (beta.9+), report formats, GitHub annotations | `build-run-test.md#Test` | Very deep — sharding math, flaky-vs-fail exit code split, `--affected`'s ~10 refusal reasons |
| `run --command` one-shot headless Editor-command execution | `build-run-test.md#run --command` | Worked C# example end to end |
| Reserved batch flags (`-batchmode`/`-quit`/`-projectPath`/`-useHub`/`-hubIPC`) and case/spelling-insensitive rejection | `build-run-test.md` lines 24-30 | Exact error text, applies to `run`/`test`/`build --args`/`open --args` |
| `projects clean` / `projects verify` / `editors prune` guardrails | `projects-templates.md#projects clean`, `#projects verify`; `editors-install.md#editors prune` | Confirmation requirements, `--dry-run`, refuses-while-open behavior |
| `vcs` command family (git hygiene, `Library/` handling implicitly via `.gitignore` guidance, merge-setup for scenes/prefabs, `affected`) | `version-control.md` (whole file) + `SKILL.md` lines 300-330 (`.gitignore` for `Library/`) | Already has git hooks, UnityYAMLMerge wiring, branch-safety refusals |
| Proxy resolution priority | `config-hub.md#config proxy` | 5-level priority list |
| CI scaffolding (`unity ci init`, `doctor --ci` preflight, sharded-matrix build recipe) | `diagnostics-maintenance.md` lines 53-135 | Generates working GitHub Actions/GitLab CI, license-seat teardown step |
| Consent/telemetry model (analytics opt-in vs the separate unconditional "cli telemetry" ping) | `diagnostics-maintenance.md` lines 242-268 | Two distinct telemetry channels, both documented with opt-out vars |
| Security posture / accepted-risk register | `SECURITY.md` (whole file) | `SEC_POWER_CAP` (local eval), `SEC_INSTALL_PIPE`, `SEC_AGENT_CONFIG_WRITE` — Unity's own threat model for exactly the live-control surface this plugin wraps |

**Conclusion for plugin scope:** none of the above needs re-documenting. The plugin's job is workflow sequencing, verification gates, and guardrails **around** these documented primitives — not restating flags.

---

## C. Live-editor model

**Registration mechanism.** Commands are registered project-side via the `[CliCommand]` attribute (namespace `Unity.Pipeline.Commands`, assembly `Unity.Pipeline`, shipped by the `com.unity.pipeline` UPM package) on a `static` method placed in an Editor assembly. `[CliArg]` marks parameters. `MainThreadRequired` (default `true`) and `RuntimeOnly` are **named properties on `[CliCommand]`**, not separate attributes. No CLI release is required to add a new command — it's discovered live. — `integration-advanced.md:546-582`

**Minimum versions:** Unity **6.0+** for the project (`com.unity.pipeline` requirement) — `SKILL.md:26`. Pipeline package registry versions observed live: `0.7.0-exp.1` (latest) down through `0.2.0-exp.2` (`unity pipeline list-versions` output, this session). `pipeline`/`command`/`status` were **promoted from development-only to production** in CLI `0.1.0-beta.8` — `CHANGELOG.md` beta.8 entry ("Changed" section) / `integration-advanced.md:201`.

**`unity list` vs bare `unity command`:** `unity list` is **discovery/introspection only** — prints every registered tool with name, description, group, and parameter schema, without executing anything. Bare `unity command` (no command name) also lists, but **executing** happens via `unity command <name> [args]`. The authoritative catalog for scripting is always `unity command --format json`. — `integration-advanced.md:356-373, 385-388`

**`--detach` / job lifecycle — a documentation gap in the GitHub skill itself.** `unity command --detach` and `unity job status|wait|cancel <job-id>` shipped in CLI `1.0.0-beta.4` (`CHANGELOG.md:115`) and still exist in the beta.8 command tree (`unity job --help` lists `status`/`wait`/`cancel`), but **no reference file documents their semantics** — I grepped every reference file and `SKILL.md` for "detach"/"job" beyond the changelog line and the one shared-target-resolver mention (`integration-advanced.md:11`); there is no section explaining detached-job state machine, polling cadence, timeout behavior, or job-ID format. This is a real hole a guardrail skill should fill (see Gaps, section G).

**`eval` semantics and limits:** `eval` / `eval_file` are **optional, package-provided built-in commands** (not guaranteed present — "discover it at runtime with `unity command` / `unity list` rather than assuming it") that run arbitrary C# in the connected Editor: `unity command eval "return Application.unityVersion;"` / `unity command eval_file snippet.cs`. — `integration-advanced.md:375-379`. No dedicated timeout, sandboxing, or output-size limit is documented beyond the generic `unity command --timeout <seconds>` (default 30s) that governs every `command` invocation including `eval`. Security posture: accepted as `SEC_POWER_CAP` — "runs entirely on the local machine, as the current user... no privilege the user lacks at their own terminal" (`SECURITY.md:11,30-32`). No mention of eval output truncation, stack-overflow/infinite-loop protection, or how a hung `eval` is recovered short of the command timeout.

**`unity run --command` headless execution:** boots a **fresh batch Editor each time** (no warm reuse across separate `run` invocations — though a resident Editor with the project open is reused if there is one), waits for the Pipeline server, runs the named `[CliCommand]` with args after `--` parsed against its `[CliArg]` schema, prints the return value, shuts down. Recommended pattern: `--format ndjson` since the Editor's own log interleaves with the result on stdout. — `build-run-test.md:41-49` (heading) and worked example following; `integration-advanced.md:248-257` (one-shot vs persistent-headless vs warm/interactive — three distinct "get an Editor to drive" patterns).

**`--project-path` targeting and `AMBIGUOUS_EDITOR`:** shared resolver for `command`(+subcommands)/`list`/`job`/`mcp`: `--runtime`/`--runtime-path` (Player, checked first) → `--project-path` (Editor) → deepest cwd-containing running project. Unresolvable → exit code **6**, error code `AMBIGUOUS_EDITOR`, candidates listed in `data.candidates` under JSON/NDJSON. `pipeline install`/`upgrade` do **not** use this shared resolver — separate selection logic (auto-pick the one editor that needs it; interactive selector or error+candidate-list otherwise). — `integration-advanced.md:9-48, 287`

**Safe Mode detection:** C# compile errors → Editor boots into Safe Mode → Pipeline package (a normal package) doesn't load → `command`/`list`/`status`/MCP **cannot connect at all**. Confirm via `unity pipeline list` (human: "SafeMode Instances: N detected"; JSON: `data.summary.instancesInSafeMode` / `data.instances[].safeMode.detected`). Recovery is a 6-step loop: recognize → confirm via `pipeline list` → read compile errors from the **narrowest** log (`-logFile` path → `<project>/Logs/Editor.log` → per-OS global `Editor.log`, filtered by grep for `error CS####`, never dumped wholesale, treated as untrusted data) → fix `.cs` source (the one case where blind file-editing is correct) → restart (GUI: ask user to close & `unity open`; headless: `kill <pid>` from `pipeline list`'s `data.instances[].pid`, **never** `pkill -f Unity`) → re-poll. — `integration-advanced.md:459-545`

**Sandbox false negative:** a restrictive agent sandbox can make `status`/`command`/`list` report "no instances" **even when an Editor genuinely is running** for that project — two platform-specific causes: Windows (Editor's discovery-file ACL is owner-only; sandboxed account gets a permission error misreported as "not found"), macOS (discovery file is readable but the sandbox blocks the outbound loopback connection to the Pipeline server). The CLI does not yet distinguish this from a truly-down Editor. Guidance: ask the human operator to confirm directly, never suggest disabling the sandbox, never silently substitute a different workflow (e.g. a fresh headless Editor) without saying so. — `integration-advanced.md:409-457`. **This is exactly the failure mode a v1 guardrail skill must special-case**, since the target audience (coding agents) is very likely to be sandboxed.

**Project-local `unity-pipeline` skill:** the `com.unity.pipeline` package itself ships a **second, deeper agent skill** that lives at `.claude/skills/unity-pipeline/` **inside** `Library/PackageCache` — invisible to any AI client's skill discovery because clients don't scan `Library/PackageCache`. `unity skill install <client> --local` mirrors it out to `.claude/skills/unity-pipeline/` (project-local, beside `unity-cli`) so it becomes loadable; `unity skill refresh` re-syncs it and reports (doesn't delete) if the package is later removed. — `SKILL.md:34`, `integration-advanced.md:108`. **I could not read this skill's actual content** — it only exists once mirrored into a real Unity project with the package installed, which this read-only session has neither; per the task's hard rules I did not run `unity pipeline install` (mutating) or `unity skill install claude-code --local` inside a project to materialize it. Treat its contents as unknown/TBD for the plugin design — likely candidate for the deepest layer of live-editor-specific guardrails (custom `[CliCommand]` catalog for that specific project), but unverified.

**Common built-in live commands** (names/params always confirmed via `unity command`/`unity list` at runtime, not hardcoded): `create_gameobject`, `find_gameobjects`, `get_scene_hierarchy`, `set_transform`, `add_component`, `rename_gameobject`/`delete_gameobject`, `save_scene`/`save_all`, `create_script`→`recompile`→`attach_script`, `screenshot` (new in `0.1.0-beta.8`), `eval`/`eval_file` (optional). Round-trip latency against an already-loaded Editor: **~200–600 ms, no script recompile, no domain reload** — the stated reason to prefer driving a live Editor over a cold `unity run` per action. — `integration-advanced.md:203-206, 360-379`

---

## D. Batch model

**`build`:** three mutually-distinguished strategies — Unity 6+ **Build Profile** (`--profile`, defines its own target), **built-in desktop player build** (`--target` + required `--output-path`), or **custom `--execute-method`** (your C# method owns the actual build and must itself honor `--output-path`, passed to it as `-buildOutput`). Non-desktop targets require `--profile` or `--execute-method`. Log: always written to `<project>/Logs/build-<target>-<timestamp>.log` (or `--log-file`) **and** tailed to stdout simultaneously by default; `--no-tail` writes file-only (also suppressed by `--quiet`/`--format ndjson`). Android keystore: `--android-keystore-base64` is decoded to a **temp file before the build and deleted after** — including on interrupt (SIGINT/SIGTERM handler scrubs it before exit, exit codes 130/143 preserved instead of a generic 1). Explicit warning that these secret flags land in shell history / CI logs / `argv` regardless of whether the value came from an env var. `--timeout` (env `UNITY_BUILD_TIMEOUT`) is **disabled by default**. Provenance manifest written for every build that reaches the editor (success or failure), redacted of secrets/paths/hostname, reported as `data.provenance` under JSON/NDJSON. — `build-run-test.md:290-366`

**`test`:** `--mode EditMode|PlayMode` (omit → editor default), `--filter`, sharding (`--shard n/m` + `--shard-inventory`, needs a seed full-run first), `--retries 0-10` with pass-on-retry reported as **flaky** (exits 0 — flakiness doesn't fail the job, it's reported in human/JSON/file output), `--rerun-failed` (reads the previous NUnit report, writes to a derived `*.rerun.xml` path so it never clobbers the full-suite record), `--coverage`/`--coverage-output`/`--coverage-options` (requires the Code Coverage package; warns and continues if absent), `--report-format nunit|junit|nunit,junit` (JUnit written even on failure, native to GH Actions/GitLab), `--affected`/`--affected-compare`/`--since` (beta.9+ only, **not in installed beta.8** — see section A). `--affected`, `--affected-compare`, `--shard`, `--rerun-failed` are mutually exclusive, exit **2** if combined. `--timeout` (env `UNITY_TEST_TIMEOUT`) **disabled by default**. **Exit code 8** is reserved exclusively for "tests ran, one or more failed" — every other failure mode (compile error, no license, editor crash, timeout) is exit **6**, specifically so CI can distinguish "retry me" from "don't retry, tests are actually red." — `build-run-test.md:103-286`, `SKILL.md:141`

**`run`:** generic batch-mode executor, forwards args after `--` verbatim to the Unity binary; manages `-batchmode`/`-quit`/`-projectPath` itself and rejects (before launch, exit 6) any of those five reserved flags including `-useHub`/`-hubIPC`, spelling/case-insensitively (`-projectPath`, `--projectPath`, `-projectPath=x` all match). `--command <name>` switches it into one-shot headless Editor-command execution (see section C). `--timeout` (env `UNITY_RUN_TIMEOUT`) **disabled by default**; on timeout, SIGTERM then SIGKILL after 2s, exit 6. — `build-run-test.md:9-49`

**`open` / `close`:** `open` matches the Hub project registry first (exact name → glob with interactive disambiguation → falls back to filesystem path), auto-selects the correct Editor version. `close <project>` — **confirmed: "exits without saving."** Exact text from local `--help`: *"Close the Unity editor that has a project open (exits without saving)"* and from the reference doc: *"Neither path saves your work: the editor exits with no save prompt, so save first."* Default path asks the editor to quit gracefully and waits `--timeout` (default 30s); `--force` sends SIGTERM then SIGKILL immediately once the graceful channel isn't available or the wait expires. — local `unity close --help`; `SKILL.md` command table line 240 ("Close the Unity editor that has a project open (exits without saving)").

---

## E. Foot-guns and destructive edges an agent skill must guard

| Foot-gun | Exact command | Documented consequence | Cite |
|---|---|---|---|
| Close discards unsaved work | `unity close <project>` | "exits without saving" / "no save prompt, so save first" — no diff/dirty check before closing | `close --help`; `SKILL.md:240` |
| `eval` runs arbitrary C# with no sandbox | `unity command eval "<code>"` | Full local-user privilege; only mitigation is the 30s default `--timeout` on `command` | `integration-advanced.md:375-379`; `SECURITY.md:30-32` |
| Kill-by-name takes down every open Editor | `pkill -f Unity` / `killall Unity` / Task Manager "end all Unity" | Explicitly warned against in Safe Mode recovery — takes out unrelated projects' unsaved work; use PID from `pipeline list` instead | `integration-advanced.md:539-540` |
| `projects clean` deletes `Library`/`Temp`/`Logs` | `unity projects clean [project] [--yes]` | Forces a slow full reimport next open; **if the CLI can't tell an editor has it open, it warns and proceeds anyway** (doesn't hard-block) — close editors first in automation | `projects-templates.md` (`#projects clean`) |
| `editors prune --remove` uninstalls editors | `unity editors prune --remove --yes` | Permanently uninstalls any editor version no registered project references — report-only without `--remove`, but `--yes` bypasses the confirmation in CI | `editors-install.md:128-142` |
| `--allow-install` silently downloads a full Editor (GBs) | `unity run/test/build --allow-install` | Installs the project's pinned editor version if missing, with no size/consent prompt beyond the flag itself — appropriate for CI, dangerous as an unattended agent default | `build-run-test.md` (flag table, all three commands) |
| Android keystore secrets leak into shell history / CI logs | `unity build --android-keystore-base64/--android-keystore-password/--android-key-alias-password` | Explicit warning: value appears in `argv` even when sourced from an env var; must additionally mask in CI log output | `build-run-test.md:347` (also flagged inline in local `--help`) |
| Pager can hang a non-interactive agent shell | `unity command` (bare listing), `releases`, `editors`, `changelog`, `logs` on a TTY | Pipes through `less -RFX`; only auto-bypassed for redirected stdout / machine formats / `--quiet` / `TERM=dumb` — an agent shell that reports as an interactive TTY without setting `--no-pager` can block waiting for `q` | `SKILL.md:90` |
| `projects list` pages **in-process**, independent of the above | `unity projects list` on a TTY | 10 projects/screen, waits for keypress; **`--format tsv`/`--format github` do NOT bypass it** on a TTY (opposite of the external pager) — must redirect stdout or pass `--no-pager` | `SKILL.md:86-88` |
| First-run consent prompt can block a non-interactive-looking session | any command, first invocation | One-time analytics consent prompt on an interactive terminal; `UNITY_NON_INTERACTIVE` alone does not suppress it — must set `UNITY_NO_CONSENT_PROMPT` (does not record a choice) or `unity analytics opt-in/opt-out` (records one) | `SKILL.md:119`; `diagnostics-maintenance.md:246` |
| `run`/`test`/`build` timeouts are **off by default** | `unity run` / `unity test` / `unity build` | Only `unity command` defaults to a timeout (30s); a hung headless Editor in these three will run indefinitely unless `--timeout`/`UNITY_*_TIMEOUT` is set explicitly | `run/test/build --help` (local); `build-run-test.md` |
| `--force` / `--yes` combinations skip real confirmations | `projects clean --yes`, `editors prune --remove --yes`, `self-uninstall --yes/--purge`, `install-modules --force` (implies `--reinstall`, auto-includes child modules) | Each of these is "required" in non-interactive contexts specifically *because* it removes a human check — a wrapper skill defaulting to `--yes` everywhere defeats the guardrail Unity built in | multiple ref files, see per-command sections above |
| Stopping an in-flight `unity build` does NOT always clean up | Ctrl-C / SIGTERM on `unity build` | Exit code preserved as 130/143 (good), and the Android keystore temp file IS scrubbed — but no equivalent guarantee is documented for other in-flight side effects (partial build output, provenance manifest still gets written on failure) | `build-run-test.md:351-353` |
| `unity install`/`install-modules --dry-run` still contacts network to resolve module list | (documented for awareness, not directly executed here) | `--dry-run` only skips writing to disk, not the release-feed/registry fetch — not "fully offline" | `editors-install.md` (Install / install-modules sections) |
| `unity self-update`/`self-uninstall` can replace or remove the CLI binary the agent itself depends on | `unity self-update`, `unity self-uninstall [--purge]` | Mid-session CLI replacement/removal would break every subsequent `unity` call in the same agent session | `diagnostics-maintenance.md:343-397` |

---

## F. Machine-readability

**Clean `--json`/`ndjson`:** `editors --json` (verified live this session — clean array of objects), `pipeline list --format json` / `pipeline list-versions --format json`, `status --format json` (`data.instances[]`), `command --format json` (full schema catalog), `test --format json`/`--format github` (GH Actions annotations via `::error::`/`::warning::`), `build --format json`/`ndjson` (progress frames `{"type":"progress",...}` + terminal envelope, verified structure in docs), `doctor --format json` (verified live — flat key/value + `recentLog.N` rows), `projects size --format json` (raw bytes instead of human units), `templates create/pack/delete --format json`/ndjson, `auth switch` ambiguous-account and `AMBIGUOUS_EDITOR` failures both ride `data.candidates`.

**Falls through to human table on a TTY (needs explicit redirect/`--no-pager` to get clean machine behavior):** `projects list` (in-process pager engages even under `--format tsv`/`--format github` on a terminal — the one place JSON/NDJSON are the *only* formats that reliably bypass paging).

**Known-buggy failure shape:** *"A handful of commands have not migrated yet and still print `{"error": "…"}` to stderr with empty stdout"* under a non-zero exit — the skill explicitly says treat empty stdout + failure as a bug in that command, not a shape to code defensively against. Which specific commands wasn't enumerated in what I read. — `SKILL.md:438`

**Exit-code table** (canonical, `SKILL.md:131-145`):

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | General error |
| 2 | Bad arguments |
| 3 | Authentication failure (also all `cloud`/`auth` auth failures) |
| 4 | Precondition not met (no license, no floating server, etc.) |
| 6 | Command-specific failure (also all non-auth `cloud`/`auth` failures; `AMBIGUOUS_EDITOR`; reserved-flag violations; run/build timeouts) |
| 8 | `unity test` ONLY — tests ran, ≥1 failed |
| 130 | SIGINT (Ctrl-C) |
| 143 | SIGTERM (kill / CI runner timeout) — cleanup handler runs first for `build` |

**Env vars an agent should set by default** (superset of the task's suggested four): `UNITY_NO_BANNER=1`, `UNITY_NON_INTERACTIVE=1`, `UNITY_NO_PAGER=1`, `UNITY_FORMAT=json` (or pass `--format json` per call), `UNITY_QUIET=1` (optional, kills non-essential noise but also silences the human-mode build stall heartbeat — tradeoff), `UNITY_NO_CONSENT_PROMPT=1` (belt-and-suspenders alongside `--non-interactive`, since non-interactive alone doesn't suppress the first-run consent prompt per the foot-gun table above), `UNITY_NO_UPDATE_CHECK=1` (avoid background network chatter/noise in agent logs).

---

## G. Gaps — what Unity's skill does not cover, or covers weakly

| Gap | Why it matters for an agent | What I checked (and found absent) |
|---|---|---|
| **Verification-after-live-edit loop** | An agent that calls `create_gameobject`/`set_transform`/`eval` has no documented "did it actually work" pattern beyond manually calling `find_gameobjects`/`get_scene_hierarchy` afterward — no built-in dry-run/undo-diff/assert primitive | Searched `integration-advanced.md` in full; only the command *catalog* is documented, no verification pattern |
| **Waiting for domain reload / compile after a live script change** | `create_script → recompile → attach_script` is documented as a 3-step manual sequence (`integration-advanced.md:371,579-581`) requiring the caller to poll `recompile_status` until `completed` — but this pattern is ONLY described for the custom-`[CliCommand]`-authoring workflow, not generalized to "I just told the Editor to write/modify a `.cs` file some other way, now what." No documented signal for an unsolicited domain reload (e.g. triggered by the user editing a file in their IDE mid-session) | `integration-advanced.md` full text — no general domain-reload-wait primitive outside the one narrow authoring context |
| **Reading Editor.log / compile errors programmatically, outside Safe Mode** | The Safe Mode section (`integration-advanced.md:488-521`) gives a full log-reading recipe, but it's framed entirely as Safe Mode recovery. There's no equivalent "how to tail Editor.log for warnings/errors during a normal live session" guidance (e.g. a script error that doesn't trigger Safe Mode) | Checked `integration-advanced.md` and `diagnostics-maintenance.md` (`logs` command) — `unity logs` explicitly reads the **CLI's own** log, not Editor.log; no CLI command reads Editor.log directly outside the Safe Mode narrative |
| **Play-mode test loop / interactive play-mode iteration** | `test --mode PlayMode` is batch-only (spawns editor, runs, writes report, exits). No documented pattern for "enter Play mode via `unity command editor_play`, poll state, assert something, exit Play mode" as a live iteration loop — only the raw `editor_play` command is named in the built-in command table with no further elaboration | `integration-advanced.md:360-370` (one-line command table entry, no example flow); `build-run-test.md` (batch test only) |
| **Screenshot / visual verification workflow** | `unity command screenshot --output ./shot.png --width --height` is documented as a single raw command (`integration-advanced.md:303-304`) with no guidance on when/why an agent should use it, how to compare against a baseline, or how to interpret failure | Same section — one example line, no workflow around it |
| **Undo/revert strategy for live-Editor mutations** | No `unity command undo` primitive is listed in the built-in table, and no guidance on how an agent should roll back a bad `create_gameobject`/`eval` other than manually reversing it or `vcs` version control | `integration-advanced.md` built-in command table; `version-control.md` (git-level revert exists but nothing Editor-session-level) |
| **`--detach`/`job` lifecycle documentation** (also flagged in section C) | An agent needs to know: what does `unity command --detach` print (just a job ID?), what states does `job status` report, does `job wait` block forever without its own timeout, what does `job cancel` actually do to an in-flight Editor operation | Grepped every reference file + `SKILL.md` — zero dedicated section; only the `CHANGELOG.md:115` line noting it shipped in beta.4, and the one resolver-sharing mention |
| **Git hygiene specifically around `Library/`** | Partially covered (`.gitignore` snippet in `SKILL.md` bootstrap workflow, `vcs doctor` checks "ignore rules, LFS patterns, package pinning") but no explicit warning about the failure mode of accidentally committing `Library/` (repo bloat, merge hazards) or a recovery recipe if it happens | `SKILL.md:303-330`; `version-control.md` `vcs doctor` section — checks it prospectively, no remediation-after-the-fact guidance found |
| **When to prefer batch (`run`/`build`/`test`) vs live (`command`/`eval`)** | Unity's skill states the *latency* case for live (200-600ms, no reload) but doesn't give a decision framework — e.g., CI/reproducibility favors batch even for small checks; live is for interactive/iterative agent sessions only, never for anything that must be deterministic/replayable | `integration-advanced.md:203-206` gives the performance rationale only, no when-to-use-which decision guidance |
| **`unity-pipeline` project-local skill contents** | Unknown — exists only once mirrored via `unity skill install <client> --local` inside a real project with the package; this read-only session had no such project to inspect | `SKILL.md:34`, `integration-advanced.md:108` — description only, content unseen |
| **Package management is entirely out of CLI scope** | `unity` CLI has **no package-management command** at all — confirmed by the separate `unity-package-management` skill's own framing: *"The Unity CLI does not manage UPM packages, so this skill covers that gap"* and *"the CLI has no package-management command, so all package work goes through the Editor's C# API"* — any agent workflow that needs to add/remove packages must go through `Client.Add`/`AddAndRemove` via a **custom `-executeMethod`/`[CliCommand]`**, with the added `-quit`-vs-async trap the skill documents (`unity run`'s default `-quit` kills the Editor before an async `Client.Add` request completes) | `/tmp/r1_unity-package-management.md` lines 1-50 |

---

## H. Raw command inventory — `unity --help` (beta.8), with v1 agent-relevance

| Command | One-line purpose | v1 relevance |
|---|---|---|
| `analytics` | Manage analytics/telemetry consent | Low |
| `auth\|a` | Sign in/out, manage accounts | Medium — needed for CI/license flows, not core live-editor loop |
| `bug` | Report a bug to Unity | None |
| `build` | Batch build a project | **High** — core batch primitive |
| `cache` | Manage download cache | Low |
| `changelog` | CLI release notes | Low/Medium — useful for the version-drift guard from section A |
| `cloud` | Unity Cloud orgs/projects | None (out of scope per brief) |
| `collaboration\|collab` | Unity Collaboration annotations/Jira | None |
| `completion <shell>` | Shell completion script | None |
| `config` | Persisted CLI config (proxy, etc.) | Low — mostly environment/corp-network concern |
| `diagnose` | Redacted support diagnostics | Medium — useful for a "why did this fail" gate |
| `doctor` | Environment diagnostic report | **High** — preflight check (`--ci` variant is CI-shaped) |
| `editor` | Manage a single editor install | Low |
| `editors\|e` | List/manage installed editors | Medium — verify target editor exists before batch/live ops |
| `env` | Print Hub environment paths | Low |
| `hub` | Install Unity Hub itself | None |
| `install\|i` | Install a Unity editor | Medium — mutating/multi-GB; must be gated, not auto-run |
| `job` | Manage detached Editor command jobs | **High** — core to `--detach` live-editor workflows (but undocumented, see Gaps) |
| `install-modules\|im` | Install/list editor modules | Low |
| `install-path\|ip` | Set/get editor install path | Low |
| `language\|lang` | CLI display language | None |
| `license` | List active Unity licenses | Medium — CI build precondition |
| `list` | List connected-Editor tools (Pipeline) | **High** — core live-editor discovery |
| `logs` | Read/tail the Hub log | Medium — diagnostics only (not Editor.log — see Gaps) |
| `mcp` | MCP server/client config | None (explicitly out of scope for v1) |
| `modules` | List/manage editor modules | Low |
| `pipeline\|pipe` | Pipeline package install/upgrade/list/list-versions | **High** — core live-editor prerequisite + Safe Mode detection |
| `plugin` | Manage optional CLI-adjacent tools (ugs, plastic, etc.) | Low |
| `projects\|p` | Hub project registry (list/create/clean/verify/exec/…) | Medium — `verify`/`clean`/`exec` are useful guardrail primitives |
| `command\|cmd` | Execute/list commands on a connected Editor | **High** — core live-editor driver |
| `templates\|t` | Browse/create/pack/delete project templates | Low — belongs to `new-unity-project` skill's territory |
| `test` | Batch run EditMode/PlayMode tests | **High** — core batch primitive |
| `open` | Open a project in the correct Editor | **High** — but mutating (spawns/reuses a GUI process); gate behind explicit intent |
| `close` | Close an Editor **without saving** | **High** — destructive, must be gated with explicit confirmation/dirty-check guidance |
| `run` | Generic batch/headless execution | **High** — core batch primitive, also the one-shot live-command path |
| `releases` | Browse available Unity editor releases | Low |
| `self-uninstall` | Remove the CLI itself | None (destructive to the agent's own tool) |
| `shell` | Interactive/ndjson REPL, warm process | Medium — `--protocol ndjson` could matter for a high-throughput live-editor session design |
| `skill` | Install/refresh the CLI's own agent skill | Low — meta, one-time setup concern |
| `status` | Live state of connected Editors | **High** — core live-editor precondition check |
| `uninstall\|u` | Uninstall an editor version | None (destructive) |
| `self-update\|upgrade` | Update the CLI itself | None (risky mid-session; see foot-gun table) |
| `vcs` | Version control automation (git/UVCS) | Medium — relevant to the `Library/`-hygiene gap, out of core v1 loop otherwise |
| `help [command]` | Show help | Low (meta) |

---

### Files referenced (GitHub, `Unity-Technologies/skills@main`)
- `skills/unity-cli/SKILL.md`
- `skills/unity-cli/references/{integration-advanced,build-run-test,projects-templates,editors-install,auth-license-cloud,diagnostics-maintenance,config-hub,version-control,collaboration}.md`
- `skills/unity-cli/CHANGELOG.md`, `skills/unity-cli/SECURITY.md`
- `skills/new-unity-project/SKILL.md`, `skills/unity-package-management/SKILL.md`

### Local commands executed (all read-only, per hard rules)
`--version`, `--help` (root + `command`/`list`/`status`/`job`/`job status`/`job wait`/`job cancel`/`run`/`test`/`build`/`open`/`close`/`pipeline`/`shell`/`projects`/`projects exec`/`templates`/`editors`/`logs`/`diagnose`/`install`/`install-modules`/`plugin`/`plugin changelog`/`vcs`/`skill`/`skill install`/`version`), `status`, `doctor`, `env`, `editors --json`, `pipeline list --help`, `pipeline list-versions`, `skill install --list`, `skill install claude-code --dry-run`, `changelog --no-pager | head -200`.
