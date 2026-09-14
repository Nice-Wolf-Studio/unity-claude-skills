# R3 — House Conventions for a New `unity-ops` Plugin

## 1. Plugin layout (`~/Dev/Unity Claude Skills`)

`.claude-plugin/plugin.json:1-9` fields actually used — only four keys, no `skills`/`commands`/`hooks` arrays inside plugin.json itself:
```json
{
  "name": "unity",
  "description": "...",
  "version": "1.4.0",
  "author": { "name": "Nice Wolf Studio" },
  "repository": "https://github.com/Nice-Wolf-Studio/unity-claude-skills",
  "license": "MIT"
}
```
- No `allowed-tools`, no `commands`/`agents`/`hooks` keys in this plugin.json — this plugin ships **skills only**.

Repo top-level (`ls "/Users/jeremymiranda/Dev/Unity Claude Skills"`):
- `.claude-plugin/` (plugin.json only)
- `skills/` — 35 subdirs, one per skill
- `audit/` — **empty directory**, no README explaining it, no references anywhere in the repo's `.md` files (`grep -rn "audit" *.md` found only an unrelated "Project Auditor" Unity package name in `skills/unity-packages-services/references/common-packages.md:78`). Treat `audit/` as a placeholder convention with no established content shape yet — don't assume its schema, ask/decide fresh.
- `README.md`, `LICENSE` (MIT), `.gitignore` (single line: `.DS_Store`)
- **No `commands/`, `agents/`, `hooks/`, or `bin/` directories exist in this plugin.** Those conventions come from `wolf-core` instead (see §5, §4).

Dir layout convention per skill, documented in README.md's "Architecture" section (`README.md`, tail):
```
skills/
├── unity-foundations/
│   ├── SKILL.md          # Core instructions (<500 lines)
│   └── references/       # Detailed API docs (loaded on demand)
```
- Explicit **<500 line** budget for SKILL.md is stated in README.
- Progressive disclosure: "Reference files provide deeper API details that Claude loads only when needed."
- Contribution/versioning workflow (README, "Contributing" section): WebFetch updated docs → update SKILL.md/references → **bump version in `.claude-plugin/plugin.json`** → push; "users with auto-update enabled will get the changes on next startup."

## 2. Skill frontmatter conventions

**`SKILL-TEMPLATE.md`** (marketplace root, full file read) prescribes:
```yaml
---
name: skill-name
version: 1.0.0
description: Use when [CLEAR TRIGGER] - [PRIMARY ACTION]; [KEY BENEFIT/PREVENTION]
triggers:
  - "keyword phrase 1"
  - "user intent 2"
---
```
- Description formula: **`Use when [TRIGGER] - [ACTION]; [BENEFIT]`** — the house does use "Use when …" trigger form, template-mandated.
- `triggers:` list of 4-7 phrases is template-recommended.
- Skill-type decision tree: Process / Reference / Integration / Knowledge, each with a body-section checklist (Process → "N Steps (MANDATORY)" + "Red Flags - STOP" + "Verification Checklist" + "When NOT to Use"; Reference → "Quick Reference" tables + "When NOT to Use" + Examples).
- Template also specifies a `## Changelog` section with semver rules and a `## Related Resources` section (Bundled References / Bundled Scripts / External Resources).

**BUT actual Unity skills deviate from the template** — this is the load-bearing finding:
- `skills/unity-testing/SKILL.md:1-4`, `skills/unity-editor-tools/SKILL.md:1-4`, `skills/unity-foundations/SKILL.md:1-4` frontmatter is **only `name:` + `description:`** — no `version`, no `triggers:`, no `allowed-tools`. Description uses YAML block scalar (`description: >`) and does follow "Use when …" prose but not the strict template formula, e.g.:
  ```yaml
  name: unity-testing
  description: >
    Unity 6 testing guide. Use when writing unit tests, integration tests, or doing TDD with
    Unity Test Framework. Covers ... Based on Unity 6.3 LTS documentation.
  ```
- Tier-1 "correctness" skills add one custom key beyond `name`/`description`: `globs:` (e.g. `skills/unity-3d-math/SKILL.md:1-7` has `globs: ["**/*.cs"]`). This is the only custom frontmatter key found anywhere in the Unity plugin.
- **Version drift discovered**: the marketplace's copy of the same file (`~/Documents/GitHub/wolf-skills-marketplace/unity-testing/SKILL.md`) *does* have a `version: 1.0.0` line injected (diff vs Dev repo: `2a3 > version: 1.0.0`) and a slightly reformatted description (`description: >-` folded prose) — i.e. the marketplace's copy has been hand-patched to add `version:`, the Dev repo source has not. New `unity-ops` skills should decide whether to match the Dev-repo style (name+description only, no version) or the "correct" template style (name+version+description) — currently the two locations for the *same* skill disagree.

Body structure actually used (not template-driven) — sampled from `unity-testing`, `unity-editor-tools`, `unity-foundations` (all ~400-500 lines):
1. `# Title`
2. `## <Topic> Overview` prose + a `**Source:**` doc link callout
3. Multiple `## <Feature>` sections with prose, tables, and fenced C#/JSON code blocks
4. `## Anti-Patterns` (numbered list, "N. Mistake — why + fix") — this is the closest analog to "Red Flags"; **no dot-digraphs, no Mermaid, no `## Red Flags — STOP` table format** used anywhere in the Unity skills (that table format is a `wolf-core` idiom, see §6)
5. `## Related Skills` — a short bullet list naming sibling skills by name + one-line scope, e.g. (`skills/unity-testing/SKILL.md:485-489`):
   ```
   ## Related Skills
   - **unity-scripting** -- C# scripting fundamentals, MonoBehaviour lifecycle, coroutines
   - **unity-editor-tools** -- Custom editors, inspectors, and editor extensions
   ```
   This is the mechanism a Unity skill uses to "invoke" (really: point to) another skill — **plain prose cross-reference by skill name, not a slash-command or explicit chain directive** (contrast with wolf-core's `## Chain` mechanism in §6/§7).
6. `## Additional Resources` — bullet list of official Unity doc URLs.

Three distinct body **formats** are named in README.md's per-tier tables (not literally in every SKILL.md, but declared house style):
- Domain skills: prose + Core Concepts / Common Patterns / Anti-Patterns / API Quick Reference / Reference Files / Cross-References
- Tier 1 "Correctness" skills: **PATTERN format** — `WHEN` / `WRONG (Claude default)` / `RIGHT` / `GOTCHA`, verified in `skills/unity-3d-math/SKILL.md:23-170` (repeating `WRONG (Claude default): ... RIGHT: ... GOTCHA: ...` blocks)
- Tier 2 "Architecture" skills: **DECISION format** — WHEN / DECISION→Options / SCAFFOLD / GOTCHA
- Tier 3 "Domain Translation" skills: **DESIGN INTENT format** — DESIGN INTENT / WRONG / RIGHT / SCAFFOLD / DESIGN HOOK

Typical length: 400-500 lines per SKILL.md (measured: unity-testing 497, unity-editor-tools 414, unity-foundations 449), 2-5 files per skill dir, `references/` holds 1-3 deep-dive `.md` files per skill (e.g. `unity-testing/references/test-framework.md`; `unity-editor-tools/references/{custom-inspectors,editor-windows,property-drawers}.md`).

**wolf-core skills** (full files read):
- `wolf-core/skills/wolf-verification/SKILL.md:1-8` frontmatter:
  ```yaml
  name: wolf-verification
  description: Use when about to claim any work complete, fixed, passing, or accurate - before committing, PRing, ...
  version: 2.1.0
  category: quality-assurance
  dependencies:
    - wolf-principles
    - wolf-governance
  ```
  Custom keys beyond name/description: `version`, `category`, `dependencies` (a list of other skill names — this is wolf-core's real skill-chaining mechanism, declared in frontmatter, not prose).
- `wolf-core/skills/wolf-tdd/SKILL.md:1-4` frontmatter: `name`, `description`, `version` only (no category/dependencies).
- Body structure (both files): `# Title` → prose statement → `## The Iron Law` (fenced all-caps single-line law) → `## The Gate Function` / `## The Cycle` (numbered steps) → a table of "What Counts as Evidence" or "Red Flags" (`| Thought | Reality |` two-column table format, not prose bullets) → `## Chain` section at the very end naming which skills call this one and which skill(s) it calls next, e.g. (`wolf-tdd/SKILL.md`, tail):
  ```
  ## Chain
  - Entered from `wolf-design` once the design is agreed.
  - On an unexpected failure mid-cycle → `wolf-debugging`
  - **REQUIRED SUB-SKILL before claiming done:** `wolf-verification`
  ```
  This `## Chain` + `| Thought | Reality |` table + single ALL-CAPS "Iron Law" line is a distinct, stricter house idiom than the plain Unity-plugin "Related Skills" bullet list — **the two plugins currently use two different cross-referencing conventions.** `unity-ops`, sitting adjacent to the `unity` plugin but philosophically closer to a guardrail/workflow plugin like wolf-core, should pick one deliberately (design decision, not free).

## 3. Marketplace registration

`~/Documents/GitHub/wolf-skills-marketplace/.claude-plugin/marketplace.json` — the `unity` plugin's entry (full block, ~35 lines):
```json
{
  "name": "unity",
  "description": "Unity 6 game development suite (...)",
  "source": "./",
  "strict": false,
  "skills": [ "./unity-2d", "./unity-3d-math", ... 35 total paths ... ]
}
```
- `source: "./"` — **local path, relative to the marketplace repo root**, not a git-subtree or URL. Every plugin in this marketplace uses `"source": "./"` (wolf-core, wolf-automation, coordination, trading, architecture, reasoning, unity — all identical pattern) with `strict: false`.
- The plugin's actual **version comes from `.claude-plugin/plugin.json` inside the plugin's own directory**, not from marketplace.json (marketplace.json has no version field per-plugin at all — confirmed by grep, none of the plugin blocks carry a `version` key).
- **A `unity-ops` plugin entry would need**: a new top-level object in the `plugins` array with `name`, `description`, `source: "./"` (or wherever its dir lives relative to marketplace root), `strict: false`, and a `skills` array of `./<skill-dir>` paths — mirroring the `unity` block exactly.

**Version bumping**: no automated bump script found; convention (per unity README "Contributing" section, §1) is manual: bump `plugin.json` `version`, then push. `CHANGELOG.md` (marketplace root, 82KB, Keep-a-Changelog format) is maintained by hand per release — e.g. `## [2.14.0] - 2026-07-18` entries describe what changed and why, referencing exact skill/version bumps and runtime-copy reinstalls. **A new `unity-ops` plugin's first release should get its own dated `## [x.y.z]` CHANGELOG entry** following this format.

**`PLAN.md`** (marketplace root) is a living enhancement-plan doc, not a per-plugin template — it documents "3 Critical Patterns" the marketplace is retrofitting onto all skills: (1) "REQUIRED NEXT SKILL" callouts, (2) "Red Flags - STOP" sections, (3) "Verification Checklist"s with pass/fail criteria — explicitly modeled on the `superpowers` plugin. This is aspirational/marketplace-wide, not unity-specific; **the Unity skills examined do NOT yet follow it** (no "REQUIRED NEXT SKILL", no Red-Flags table, no Verification Checklist in unity-testing/unity-editor-tools/unity-foundations). A new `unity-ops` plugin, being guardrail/workflow-shaped, is a better candidate to actually implement PLAN.md's 3 patterns than the existing reference-style `unity` plugin was.

**`scripts/`** (marketplace root) holds three paired `.ts`+`.test.ts` tools with READMEs: `skill-discovery.ts`, `template-validator.ts`, `cleanup-context-files.ts` — no `test-skills.sh` in this directory (confirmed absent by `find`).

**`test-skills.sh`** actually lives at `~/.claude/skills/test-skills.sh` (the *installed runtime* location, not the marketplace source) — full script: a bash harness that runs `node $HOME/.claude/skills/<skill>/scripts/query.js ...` commands and greps expected substrings out of stdout, per skill (wolf-principles, wolf-archetypes, wolf-roles, ...). **This only validates skills that ship an executable `scripts/*.js` — it is not a general SKILL.md linter.** The Unity skills ship no `scripts/`, so this harness has nothing to test for them; `unity-ops`, if it ships CLI-wrapping scripts, would need its own equivalent entries or its own test harness.

**Relation between `~/.claude/plugins/marketplaces/wolf-skills-marketplace/unity/skills/` and `~/Dev/Unity Claude Skills/skills/`**: these are **two independently git-managed copies of the same content, not a symlink or subtree**.
- `~/Dev/Unity Claude Skills` — remote `origin = https://github.com/Nice-Wolf-Studio/unity-claude-skills.git` (confirmed via `git remote -v`); own commit history (`b954dcc`, `ad7de73`, `5ef9dd2`, ... 6 commits) independent of the marketplace repo.
- `~/Documents/GitHub/wolf-skills-marketplace` — remote `origin = https://github.com/Nice-Wolf-Studio/wolf-skills-marketplace.git`; the unity skill dirs entered this repo via a **squash migration commit** `dfd89be feat: migrate 41 global skills into marketplace (unity suite, architecture trio, graphify, plan, wolfloop) — v2.9.0` — a one-time copy-in, not an ongoing sync (no submodule entry for unity in `.gitmodules`, which only lists `coordinate` → `wolf-coordination-protocol`).
- Content has since **drifted**: diffing `unity-testing/SKILL.md` between the Dev repo and the marketplace repo shows the marketplace copy gained a `version: 1.0.0` frontmatter line the Dev repo doesn't have (§2). Diffing against the **installed plugin cache** (`~/.claude/plugins/cache/wolf-skills-marketplace/unity/1.0.0/skills/unity-testing/SKILL.md`) shows a *third*, further-reformatted variant (rewritten description prose, `description: >-` instead of `description: >`).
- The plugin **cache is stuck at version `1.0.0`** (`~/.claude/plugins/cache/wolf-skills-marketplace/unity/1.0.0/.claude-plugin/plugin.json` — `"version": "1.0.0"`) while the Dev repo's plugin.json says `1.4.0` — i.e. **the installed/cached plugin is stale relative to the Dev repo's current version number**, and the marketplace source-of-truth for what actually ships is whatever is checked into `~/Documents/GitHub/wolf-skills-marketplace/unity-*/`, not the Dev repo. **Practical implication for `unity-ops`: publishing changes in `~/Dev/Unity Claude Skills` does nothing for users until someone manually copies/re-authors the same files into the marketplace repo — there is no automated sync today.**

## 4. PATH / bin wiring

- The Unity **CLI itself** (`unity`, the actual binary) is installed at `/Users/jeremymiranda/.unity/bin/unity` and added to PATH via `/Users/jeremymiranda/.unity/env`, sourced from `~/.zshrc:46` (`. "/Users/jeremymiranda/.unity/env"`). This is a **separate installer-managed mechanism**, unrelated to Claude Code plugins entirely — it's how the Unity Editor's own CLI installer wires itself into the shell, the same pattern Cargo/rustup or nvm use (`case ":${PATH}:" in *:"...":*) ;; *) export PATH=... ;; esac` idempotency guard).
- **Correction of a premise in the brief**: `~/.claude/plugins/cache/wolf-skills-marketplace/unity/1.0.0/bin` does not merely exist-and-be-empty — it **does not exist at all** (`ls` → "No such file or directory"; `find .../unity/1.0.0 -maxdepth 2` lists only `.in_use`, `.claude-plugin`, `skills`). There is no `bin/` shipped by the `unity` plugin today, cached or otherwise.
- **No plugin in this marketplace ships a `bin/` directory** — `find ~/.claude/plugins/cache -maxdepth 3 -type d -name bin` returned nothing. `wolf-scripts-core` (the marketplace's "automation scripts" skill, cited in the brief as a possible bin/ example) is in fact just a single `SKILL.md` file (`wolf-core/skills/wolf-scripts-core/SKILL.md`) with **no `bin/` or `scripts/` subdirectory** — it's a reference/knowledge skill, not a script-shipping one.
- **Conclusion**: there is no established "ship a `bin/` with the plugin and expect it on PATH" convention anywhere in this marketplace. If `unity-ops` needs to invoke the `unity` CLI, it should assume the CLI is already on PATH via the user's own `~/.unity/env` installer wiring (as it is here) and simply shell out to `unity ...`, rather than trying to vendor or wire its own `bin/`. If `unity-ops` ships helper scripts, the closest precedent is skills with a `scripts/` subdir invoked via `node $HOME/.claude/skills/<skill>/scripts/*.js` (per `test-skills.sh`) — i.e. scripts live inside the **skill's own directory**, not a plugin-level `bin/`, and are invoked with an explicit interpreter + full path, never assumed to be on PATH.

## 5. Hooks & session-init

`wolf-core/hooks/hooks.json` (full file):
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "test -f \"${CLAUDE_PLUGIN_ROOT}/hooks/wolf-session-start\" && bash \"${CLAUDE_PLUGIN_ROOT}/hooks/wolf-session-start\" || true",
            "async": false
          }
        ]
      }
    ]
  }
}
```
- Mechanism: a `SessionStart` hook matching `startup|clear|compact`, guarded by `test -f ... || true` so a missing script degrades silently rather than breaking session start.
- The hook script `wolf-core/hooks/wolf-session-start` (bash) implements a **dedup guard** (per-session-id + per-source lockfile in `$TMPDIR`, so if the same hook is registered by more than one enabled plugin sharing a source dir, only the first copy injects) and then **injects the full body of `skills/using-wolf/SKILL.md` into context**, wrapped in an `<EXTREMELY_IMPORTANT>` tag, reading `PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-...}"` and `SKILL_FILE="$PLUGIN_ROOT/skills/using-wolf/SKILL.md"`.
- **Decision this gives `unity-ops` for free**: the precedent for "run something at session start" is a `hooks/hooks.json` + companion bash script pair, referenced via `${CLAUDE_PLUGIN_ROOT}`, gated by a `test -f` existence check, with a dedup lock if collision across plugins is possible. If `unity-ops` wants to run `unity status --json` (or similar) at session start, it should follow this exact shape: `hooks/hooks.json` (SessionStart, matcher `startup|clear|compact`) → `hooks/<script-name>` bash script that `command -v unity >/dev/null 2>&1 || exit 0` (fail-open, mirroring wolf-core's `command -v jq ... || exit 0` and missing-file guards) before calling the CLI, so a machine without the Unity CLI/without an open Unity project doesn't break every session start for non-Unity work.
- `wolf-core/.claude-plugin/plugin.json` shows the same 4-key shape as unity's (`name`, `version: "1.3.0"`, `description`, `author`) — hooks are declared in the separate `hooks/hooks.json`, not in plugin.json itself.

## 6. Wolf evidence contract (for unity-ops skills to emit evidence in the same shape)

From `wolf-verification/SKILL.md` (quoted):
> "NO COMPLETION OR FACTUAL CLAIM WITHOUT FRESH VERIFICATION EVIDENCE" — "'Fresh' means produced by you, now, for this claim — not remembered, inferred, or copied from an earlier state of the work."

Gate Function (5 steps, quoted): **IDENTIFY** what would prove the claim → **RUN** it now → **READ** full output → **VERIFY** output actually supports the claim ("Partially supported = unsupported") → only then **CLAIM**, stating the evidence with it.

"What Counts as Evidence" table (quoted rows most relevant to a Unity CLI context):
| Claim | Requires | Not sufficient |
|---|---|---|
| "Tests pass" | Full test run output, just now | Previous run; "should pass"; partial suite |
| "Bug is fixed" | Repro case failing before, passing after | The code "looks right" |
| "Builds cleanly" | Fresh build output with zero errors/warnings-as-errors | Editor showing no red |
| "File/function exists" | Read or grep output from this session | Memory of the codebase |

Batch-edit rule (quoted): "**Never abort mid-batch.**" / "**Grep every edit after writing.**" / "**Report and commit only what verified**" — "reporting a change as applied requires diff or grep proof of that exact change."

Implication for `unity-ops`: any skill that claims "the scene compiles", "the test suite is green", "the build succeeded" must be wired to actually invoke `unity` CLI subcommands (build/test) and quote/parse their fresh output as the evidence — never infer success from the Editor's last-known state or from a prior session's run. A "Batch Edits"-style rule applies directly to any workflow that touches multiple `.cs` files or multiple scenes: verify each file individually (grep/diff), not just an aggregate exit code.

From `wolf-tdd/SKILL.md` (quoted): **"NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST"** — RED (write test, run it, watch it fail for the *expected* reason) → GREEN (minimum implementation, run full suite not just the new test) → REFACTOR (no behavior change, suite green before/after). "**REQUIRED SUB-SKILL before claiming done:** `wolf-verification`" — i.e. wolf-tdd itself chains into wolf-verification via the `## Chain` section, not by name-check but as an explicit required step.

## 7. Naming rules

- **No explicit kebab-case rule document was found**, but it is the observed convention with zero exceptions across all 35 unity skill directory names, all wolf-core skill names, and the marketplace plugin names (`unity`, `wolf-core`, `wolf-automation`, `wolfnotes`, `trading`, `architecture`) — kebab-case throughout, several with a `unity-`/`wolf-` prefix signaling family membership. A hypothetical `unity-ops` plugin fits this pattern directly.
- **Namespacing confirmed via `~/.claude.json`**: enabled-plugin tracking keys are `<plugin-name>@<marketplace-name-or-"inline">`, e.g. (`.claude.json:1748-1758`):
  ```json
  "unity@inline": { "lastUsedAt": ..., "usageCount": 0 },
  "unity@wolf-skills-marketplace": { "lastUsedAt": ..., "usageCount": 52 },
  ```
  confirming the **same plugin name (`unity`) is independently tracked per-source** (a local `--plugin-dir`/dev install vs. the marketplace install) without collision — the `@source` suffix disambiguates.
  Skill-level usage stats, by contrast, are a flatter namespace: some entries are bare skill names (`"unity-3d-math": {...}`, `.claude.json:6827`) and others are plugin-qualified (`"wolf-core:wolf-debugging": {...}`) — i.e. **skill identity in this stats dict is not consistently namespaced**; whichever string Claude Code used to invoke the skill is the key.
  README.md (`unity` plugin) documents the invocation form explicitly: "You can also invoke them directly with `/unity:<skill-name>`" — i.e. the **canonical addressable form for a plugin skill is `plugin-name:skill-name`**, matching the `wolf-core:wolf-debugging` stats key.
- **Coexistence check**: `~/.claude/skills/unity-cli` does **not currently exist** (`ls` → No such file or directory; the only standalone user-level skills present are `github`, `use-railway`). So there is no live example of a name collision to observe directly. But the evidence above (plugin-qualified `plugin:skill` addressing, e.g. `wolf-core:wolf-debugging`, vs. bare-name addressing for standalone `~/.claude/skills/<name>` skills) indicates a plugin skill `unity-ops:foo` and a standalone `~/.claude/skills/unity-cli` named `unity-cli` **would not collide as identifiers** (`unity-ops:foo` vs. bare `unity-cli`) — they're namespaced differently by construction, one always carrying its plugin prefix, the other never. The residual risk is not identifier collision but **trigger overlap**: if both skills' `description:`/trigger phrasing target the same Unity-CLI keywords, Claude may be uncertain which one auto-invokes; that's a discoverability/description-writing problem, not a namespace problem, and isn't resolved by any file found here.
- `claude --help` confirms skills resolve by slash command even with plugins disabled: "`--disable-slash-commands` Disable all skills" and (separately) "Skills still resolve via `/skill-name`" appears in the flag help text for a related isolation flag — consistent with bare-name resolution for standalone skills and `plugin:skill` for plugin-provided ones.

## 8. Existing personality/response constraints affecting skill body style

From the user's global `~/.claude/CLAUDE.md` (as provided in this session, quoted verbatim):
- Terseness/structure mandate, directly relevant to how `unity-ops` SKILL.md prose should read: *"Structure over prose for anything enumerable — table, short list, named components. Paragraphs only for a claim that needs an argument."* and *"Terse is about word count, not substance. Never drop evidence, `file:line` anchors, a failing test, or a real blocker to sound brisk."*
- *"NEVER spawn a task chip. File a GitHub issue."* — binds any subagent/skill workflow `unity-ops` defines that surfaces deferred work: *"This binds teammates too. Put it in every brief: findings are filed as GitHub issues, or reported back to you to file."* Any `unity-ops` skill that does multi-step review/audit work (e.g. a Unity project health-check skill) must route findings to `gh issue create` on the resolved repo (`gh repo view --json nameWithOwner`), never to a spawned chip.
- *"Clickable links MUST resolve"* — governs any file-link output a `unity-ops` skill produces (e.g. pointing at a failing test file or a `.unity` scene): must use a path that resolves from wherever the link is rendered, absolute path if unsure, absolute main-checkout path for anything not present in a worktree.
- *"run everything in the background. i hate when you spam my console"* — relevant if `unity-ops` wires long-running `unity` CLI invocations (builds, batch test runs): prefer background execution with a completion notification over streaming raw CLI output into the conversation.
- *"GitHub auth: NEVER act as jdmiranda"* — if any `unity-ops` skill/workflow pushes commits or opens PRs (e.g. an auto-fix skill), it must use `wolfagents-bot`, verified via `gh auth switch` + `gh api user --jq .login`, never the user's own `jdmiranda` identity.
- *"Always check the directory you are in."* — a standing instruction that argues for `unity-ops` skills which shell out to the `unity` CLI to always confirm cwd/Unity project root before invoking build/test commands (the CLI is project-path-sensitive).

## Constraints checklist for the unity-ops design

1. Plugin dir needs only `.claude-plugin/plugin.json` (name, description, version, author, repository, license) + `skills/` — no commands/agents/hooks required unless you opt in. — `Unity Claude Skills/.claude-plugin/plugin.json:1-9`
2. Skill dirs cap SKILL.md at roughly <500 lines, push detail into `references/*.md` loaded on demand. — `README.md` "Architecture" section
3. Marketplace registration is a hand-written block in `marketplace.json` with `source: "./"`, `strict: false`, and a `skills` array of `./<dir>` paths — version lives in the plugin's own plugin.json, not marketplace.json. — `wolf-skills-marketplace/.claude-plugin/marketplace.json` (unity block)
4. There is no automated sync between `~/Dev/Unity Claude Skills` and the marketplace copy — content already drifted once (frontmatter `version:` line added independently on each side); publishing `unity-ops` will require manually mirroring files into the marketplace repo. — diff of `unity-testing/SKILL.md` across Dev repo / marketplace repo / plugin cache
5. Installed plugin cache can lag the source repo's version (cache pinned at 1.0.0 vs. Dev repo's 1.4.0) — don't assume a version bump alone propagates to what's cached/enabled. — `~/.claude/plugins/cache/wolf-skills-marketplace/unity/1.0.0/.claude-plugin/plugin.json`
6. Actual Unity skill frontmatter in production is minimal (`name` + `description` only); SKILL-TEMPLATE.md's `version`/`triggers:` fields are aspirational, not enforced. Decide explicitly which convention `unity-ops` follows. — `skills/unity-testing/SKILL.md:1-4` vs `SKILL-TEMPLATE.md`
7. `description:` should read as "Use when X — covers Y" prose (house style, not strictly the template's semicolon formula). — `skills/unity-foundations/SKILL.md:1-4`, `SKILL-TEMPLATE.md` "Description Formula"
8. Cross-skill references in the Unity plugin are a plain `## Related Skills` bullet list, not a `## Chain` block or slash-command directive — pick one style for `unity-ops` and apply it uniformly. — `skills/unity-testing/SKILL.md:485-489` vs `wolf-tdd/SKILL.md` "## Chain"
9. wolf-core's stricter guardrail idiom (`## The Iron Law`, `| Thought | Reality |` Red-Flags table, `## Chain`) is the closer stylistic match for a guardrail plugin like `unity-ops` than the Unity plugin's own reference-skill style. — `wolf-tdd/SKILL.md`, `wolf-verification/SKILL.md`
10. No plugin in this marketplace ships a `bin/` on PATH; the empty/missing `unity/1.0.0/bin` is not a real convention to imitate — shell out to the user's already-PATH'd `unity` CLI (wired via `~/.unity/env`, sourced from `~/.zshrc:46`) instead of vendoring binaries. — `find ~/.claude/plugins/cache -name bin` (no results); `~/.zshrc:46`
11. If `unity-ops` needs a SessionStart hook (e.g. `unity status --json`), follow wolf-core's exact shape: `hooks/hooks.json` (SessionStart, matcher `startup|clear|compact`) → guarded bash script using `${CLAUDE_PLUGIN_ROOT}`, `test -f` / `command -v` fail-open checks, and a per-session dedup lock if collision is possible. — `wolf-core/hooks/hooks.json`, `wolf-core/hooks/wolf-session-start`
12. Evidence for any "it works/it built/it passed" claim must be fresh CLI output read and verified this session, never inferred from Editor state or a prior run; batch changes (e.g. multi-scene edits) need per-item grep/diff proof, not an aggregate exit code. — `wolf-verification/SKILL.md` Gate Function + Evidence table + Batch Edits section
13. TDD-shaped `unity-ops` workflows (e.g. a "write a PlayMode test first" skill) should mirror RED→GREEN→REFACTOR and explicitly chain to `wolf-verification` as the required last step. — `wolf-tdd/SKILL.md`
14. Kebab-case, family-prefixed naming (`unity-*`) is the unbroken convention; plugin identity is namespaced as `name@source` internally and addressed as `plugin:skill` externally, so `unity-ops:foo` cannot collide with a standalone `unity-cli` skill by identifier — only by descriptive/trigger overlap, which is a wording problem to manage during authoring. — `.claude.json:1748-1758,6827`; unity `README.md` ("/unity:<skill-name>")
15. Any `unity-ops` skill producing deferred findings (e.g. a project-audit or lint skill) must file GitHub issues on the resolved repo, never spawn task chips; must keep body prose terse/tabular per the user's global style; must keep file links resolvable; and any git-writing workflow must run as `wolfagents-bot`, never `jdmiranda`. — user's `~/.claude/CLAUDE.md` (quoted in §8)
