---
name: unity-cli-contract
description: >
  Use when a unity command fails with exit 2 or "unknown option"; when a subcommand's help prints
  the root help instead of its own; when the CLI hangs on a pager or a first-run prompt; when a
  flag documented in the skill does not exist on the installed binary; before parsing or scripting
  any unity output; when the unity-cli skill is not installed.
---

# Unity CLI contract

Three artifacts claim to describe the one `unity` binary on this machine — the skill copy installed at
`~/.claude/skills/unity-cli`, that same skill at GitHub@main, and the binary itself. No two of them agree,
and the disagreement is not one simple lag: it runs in both directions at once, so neither "my reference
lists it" nor "my reference says nothing about it" settles anything at all.

| Axis | Direction of drift | What it costs you |
|---|---|---|
| Installed docs → GitHub@main | Installed sits **one release behind**, pinned to the CLI release it was captured at (SK:439). Whole pages are missing locally: no version-control reference file, no sandboxed-agent section, no `ci init`, no `config get/set/list/unset`, no `auth consumers/revoke`. | A hole in the copy you loaded is not a hole in the product. |
| GitHub@main → binary | GitHub sits **one release ahead**. It documents surfaces the binary may not carry — at one capture point `unity version`, `test --affected*`, `install --list-modules` and `plugin changelog` all failed to answer — but which four drift with the build, so probe each on the binary you actually have rather than trusting this list. | A user quoting Unity's public documentation at you is usually right about the product and wrong about your binary. Do not argue with the citation; probe the binary. |
| Installed docs ↔ binary | **Both directions at once**, because a skill refresh swaps one of these two artifacts for the other. Binary-ahead today: `vcs` and `close` answer on the binary and are named nowhere in the installed docs. Docs-ahead after any refresh: the four GitHub-only surfaces above land in your reference without landing on your binary. And `--detach` / `job status\|wait\|cancel` sit on the binary undocumented in **either** written copy. | Silence in your copy is not absence on the binary. In the T3.2 baseline (three reps, 2026-09-14/15), two of the three read that silence as a denial and told the user that a capability this binary ships "does not exist at all". |

**No document is authority over the binary, in either direction. Probe first.**

## The invocation contract

| Step | Command | Rule |
|---|---|---|
| Dependency | `unity skill install --list` `[restates IA:93 — adds: the hard stop, the anchored match and the ordering]` | **Sourcing `~/.unity/env` aside, this is the first `unity` you run this session** — before `--version`, before any `--help`, before the surface the user asked about. The `claude-code` row must say installed. **Anchor the match** — `installed` is a substring of `not installed`. Not installed → stop, tell the user to run `unity skill install claude-code`, do not proceed. A version or capability answer handed over without this row having been read is not an answer, however many probes stand behind it — run the gate, then re-issue it. Never vendor, copy, or paraphrase Unity's skill. |
| CLI presence | `. "$HOME/.unity/env"; command -v unity && unity --version` | The CLI is wired onto PATH by `~/.unity/env`, sourced only from `~/.zshrc:46` — a non-login agent shell does not have it. Absent → stop and give Unity's own install command. |
| Version | parse `1.0.0-beta.N` from `unity --version` | Record N in-session. **Then open every statement about what this CLI does or does not have with the version you probed it on, in the form `on 1.0.0-beta.N, …`.** This is not conditional: presence, absence and "use this instead" are all version-dependent, and a capability claim that names no version is not an answer — it is a sentence the user cannot check. **Do not compare N against either changelog** — compare it against a probe. In the T3.2 baseline, all three reps stated a version-dependent truth and not one named the binary it was true of. |
| Flag probe | `unity <parent> --help`, read its `Commands:` list | **Root help printed is never evidence of absence.** Nested subcommands have been **observed intermittently** printing the root help instead of their own — the same invocation printed root help once and correct help on three immediate re-runs, with and without env vars, piped and not, exit 0 throughout. Re-run, then probe the parent. Probe the surface that answers the *request*, not only the surface the user named: the adjacent verb often owns the capability the named one lacks (observed once, `vcs affected` next to `test`). **Then read the block you just printed to its end and name what it *does* carry** — the options already on the command are where the cheap alternative comes from, and they are the first thing to offer once the flag the user asked for turns out to be missing. Observed on one build, `unity test --help` carried `--filter`, `--shard` and `--rerun-failed`; in the T3.4 result run one rep denied a per-test filter existed and the other used one without ever offering it. Verify against the help your binary prints, not against this line. |
| Envelope | `export UNITY_NO_BANNER=1 UNITY_NON_INTERACTIVE=1 UNITY_NO_PAGER=1 UNITY_FORMAT=json UNITY_NO_CONSENT_PROMPT=1 UNITY_NO_UPDATE_CHECK=1` `[restates SK:96-119 — adds: it is mandatory, not optional, and UNITY_QUIET is deliberately excluded]` | One line, not a table. Per-variable rationale and the pager/TTY hazard are the `unity-cli` skill's (SK:84, SK:86) — go read them there. `UNITY_NO_PAGER` is defensive cover, never the explanation for why something did not hang. |
| Parse | read **stdout**, branch on `success` | `errors[0].code` is the stable token. `data` is **not** always null on failure — `unity status`'s own failure envelope carries `data.count` and `data.instances`, and `AMBIGUOUS_EDITOR` carries `data.candidates`. Empty stdout on a non-zero exit is a known CLI bug in that command, not a shape to code against (SK:434). |

## Known version gaps

> **A dated snapshot, not a reference — observed 2026-09-14/15 on one build (1.0.0-beta.8), which the machine
> has since moved off. Every row may already be wrong. Do not cite it; re-probe.** It is here to show the
> *kinds* of drift, not their current values, and it rots with every release. **The probe is the protection.**
> It also mixes two questions that are not the same question — what the *docs you loaded* lack, and what the
> *binary* lacks — so read both columns and act on the right-hand one. Check the binary.

| Surface | In the installed skill docs? | On the installed binary? |
|---|---|---|
| `unity version` (structured subcommand) | No — GitHub-only | No |
| `unity test --affected` / `--affected-compare` / `--since` | No — GitHub-only | No |
| `unity install --list-modules` | No — the installed copy teaches `--list-components` (EI:236) | No |
| `unity plugin changelog <id>` | No — GitHub-only, **though `unity plugin install plastic` is documented** (SK:286, PT:259) | Family present; `changelog` is not in its `Commands:` list |
| `unity vcs uvcs locks\|changesets\|review` | **Yes** — inline at SK:257, SK:263, SK:280 and PT:175-220 | **Yes** |
| `unity vcs setup\|status\|sync\|doctor\|providers\|affected`, `vcs git` | **No** — no version-control reference file in the installed tree and no `vcs` row in its command index | **Yes** — full verb set, `affected` among them. Run `unity vcs --help`; this cell tells you where to point the probe, not what it prints |
| `unity close <project>` | **No — undocumented anywhere in the installed skill** | **Yes**, and `unity close --help` says "exits without saving"; `<project>` is a required positional |
| `--detach`, `job status\|wait\|cancel` | No — **no reference page in either copy documents them**; the installed tree names them once, in a `CHANGELOG.md:84` note whose own point is that they went undocumented | Yes |

How to answer the "does this exist?" question without this table: `references/version-probe.md`.

## Guardrails

| Gated | Advisory in v1 | Hook pattern / promotion |
|---|---|---|
| Using any surface from the gaps table without probing it this session | Warn + probe first; a row above is a hint about where to look, never the answer | `unity-invocation` (silent telemetry) |
| Concluding a subcommand does not exist from a root-help printout — reporting any presence/absence claim that does not name the binary it was probed on — or denying something the help you have just read carries | Warn + re-run the same invocation, then re-probe via the parent's `Commands:` list; and re-state the finding as `on 1.0.0-beta.N, …` before it goes to the user. **Every absence claim names the command that printed the help and the line it rests on** — *the option list has no X* is sayable only after you have read that list to its end, and a denial the printout in your hand refutes is this skill's own failure mode, not a milder one | `unity-invocation` (reasoning, so measured rather than matched) |
| Parsing `stderr`, treating empty stdout as the failure signal, or running without the envelope on a TTY | Warn + point at `success` and `errors[0].code` (SK:434) and at the pager hazard (SK:84, SK:86) — pointers, not restatements | `unity-invocation` (silent telemetry) |
| Launching the Editor to settle a question `--help` settles — `unity test` above all — or pointing a results file into the user's project tree | Warn + stop at the probe: whether a flag exists is decided by a help printout in one second; a run decides nothing about it and spends the clock. If the run is genuinely wanted, **offer it and let the user start it**, and give `--output` an absolute path outside the project — its default and any `./name.xml` resolve against the directory you were dispatched into and leave an untracked artifact in a tree you do not own | `unity-invocation` (silent telemetry) |
| Offering the expensive alternative without pricing it against the deadline the user stated | Warn + price it before they spend it — as a **shape**, not a wall-clock number you have no way to get without the run `--output`'s row forbids: say whether it launches the Editor and puts the whole suite through it, or stays inside a narrowed scope on this binary (`unity vcs affected` scoped to one revision range, with the option its own `--help` names; plus whatever narrowing the option list you just probed carries). Under a stated clock, "run this instead" is half an answer until the user can tell whether it fits the deadline | `unity-invocation` (reasoning, so measured rather than matched) |
| Proceeding when `unity-cli` is not installed — or when `unity skill install --list` has not been run at all this session | **Hard stop from day one.** This is the dependency contract, not an advisory: stop, emit `unity skill install claude-code`, and do not run a degraded workflow from memory. **Unrun is not passed**: the gate is the session's first `unity`, and skipping it fails the contract exactly as a `not installed` row does, minus the evidence. In the T3.4 result run it was run only when the skill was force-fed. | the only v1 gate that is not advisory; it lives in this skill body, not in the hook |

## Related Skills

- **unity-ops:unity-surface-preflight** -- resolves the control surface; runs this skill as its first sub-step
- **unity-ops:unity-live-edit-verification** -- live mutation read-back and save
- **unity-ops:unity-script-change-gate** -- recompile before any claim about C# you wrote
- **unity-ops:unity-destructive-gate** -- the irreversible commands
- **unity-ops:unity-batch-hygiene** -- build/test/run launch shape
- **unity-cli** (Unity's own, `~/.claude/skills/unity-cli`) -- the command reference. Never restated here.
- References: `references/version-probe.md`, `references/mcp-optional.md`
