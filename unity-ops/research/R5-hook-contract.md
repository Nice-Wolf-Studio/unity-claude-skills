## Errata — superseded by DESIGN.md revision 4 (2026-09-14)

R5 is a research input, not a contract this design inherits unchanged. **Four** of its statements are corrected below — three superseded, one cosmetic and **`research/R5-hook-contract.md` carries this block verbatim at its head** so nobody reads the recommendation without the correction:

| R5 says | Status | Superseded by |
|---|---|---|
| Recommends an `UNITY_OPS_SCENARIO` environment variable for scenario tagging | **WITHDRAWN** — no delivery mechanism (the Agent tool takes no env parameter; an `export` does not survive to the next Bash call; the hook process is spawned by the harness) | the flag file + lock + `session_id` capture above (R2-2, R3-7) |
| Ships a guard skeleton that walks up from `$PWD` | **SUPERSEDED** — `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1` makes it exit 0 on every call this plan makes | PLAN Task 1.2's script (stdin `cwd` / `dirname(file_path)` / `unity`-fronted segment) |
| Rows 12 (`additionalContext` reaches the model) and 18 (hooks fire in subagents) | **CITED TO THE DOCS, NEVER EXERCISED HERE.** Both are load-bearing: row 18 carries the scenario tagging *and* the R3-1 trigger signal; row 12 carries every "advisory in v1" claim in §3 | PLAN Task 1.3 Part B observes both, with a per-run nonce for row 12 and a `session_id != parent` assertion for row 18, and falls back to §10 alternative C if either fails |
| Rows 12 and 18 cite bare URLs | cosmetic; re-cite with the section name when R5 is next touched | — |

# R5 — Claude Code PreToolUse hook contract (verified 2026-09-14)

Purpose: the enforcement mechanism for `unity-ops` guardrails. v1 ships one fail-open PreToolUse hook in **shadow mode** (log + optional `additionalContext` warning, always allow); promotion of a pattern to a hard gate = flipping that pattern's decision to `deny`. Verified by the claude-code-guide agent against the official docs; citations inline. One correction by the orchestrator: on this machine the Write/Edit tools carry `file_path` (see the tool schemas in this session), the docs page cited says `path` — the hook must read `.tool_input.file_path // .tool_input.path`.

| Question | Verified answer | Citation |
|---|---|---|
| PreToolUse stdin JSON | `{session_id, prompt_id, transcript_path, cwd, scratchpad_dir, permission_mode, hook_event_name, tool_name, tool_input, tool_use_id}` | https://code.claude.com/docs/en/hooks#hook-input |
| `Bash` tool_input keys | `command`, `description`, `timeout`, `run_in_background` | https://code.claude.com/docs/en/hooks#tool-input-schemas |
| `Write` / `Edit` tool_input keys | docs: `path`, `content` / `path`, `old_string`, `new_string`, `replace_all`; **this machine: `file_path`** — read both | https://code.claude.com/docs/en/tools |
| Allow | exit 0 with no stdout (normal permission flow), or JSON `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}` | https://code.claude.com/docs/en/hooks#pretooluse-decision-control |
| Deny | JSON `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}` on exit 0; or exit 2 with the reason on stderr | same; https://code.claude.com/docs/en/hooks-guide.md |
| Warn without blocking | `{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"…"}}`, exit 0 — injected into the model's context (system-reminder style), not shown in the transcript | https://code.claude.com/docs/en/hooks-guide.md (additionalContext); https://code.claude.com/docs/en/hooks#json-output |
| `matcher` syntax | exact tool name, or regex alternation `Bash\|Write\|Edit`; regex like `mcp__.*` | https://code.claude.com/docs/en/hooks-guide.md |
| Plugin hook location | `hooks/hooks.json` at the plugin root (not inside `.claude-plugin/`); same schema as settings.json `hooks` | https://code.claude.com/docs/en/plugins#plugin-structure-overview |
| Env vars in hook commands | `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PROJECT_DIR}`, `${CLAUDE_PLUGIN_DATA}` | https://code.claude.com/docs/en/hooks#security-considerations |
| Merged with user/project hooks | yes, when the plugin is enabled; no extra prompt beyond enabling the plugin | https://code.claude.com/docs/en/plugins#plugin-structure-overview |
| Default timeout | 600 s for command hooks | https://code.claude.com/docs/en/hooks-guide.md |
| Fire inside subagents | **yes** — PreToolUse hooks from settings, plugins and managed policy run for subagent tool calls | https://code.claude.com/docs/en/sub-agents |
| Per-project conditional enablement | not a built-in; the script must fail open itself (exit 0 fast when `ProjectSettings/ProjectVersion.txt` is absent) | UNVERIFIED in docs — convention |
| Security guidance | runs with user permissions; sanitize inputs; quote paths; use `${CLAUDE_PROJECT_DIR}`; scripts must be executable | https://code.claude.com/docs/en/hooks#security-considerations |

## `hooks/hooks.json` (same shape as wolf-core's SessionStart hook)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "test -f \"${CLAUDE_PLUGIN_ROOT}/hooks/unity-ops-guard\" && bash \"${CLAUDE_PLUGIN_ROOT}/hooks/unity-ops-guard\" || true"
          }
        ]
      }
    ]
  }
}
```

## `hooks/unity-ops-guard` skeleton (shadow mode)

```bash
#!/bin/bash
# unity-ops — shadow-mode guardrail hook. Logs matches; always allows in v1.
set -u
# Fail open: not a Unity project → allow immediately. Walk up from cwd.
d="${PWD}"; found=""
while [ "$d" != "/" ]; do [ -f "$d/ProjectSettings/ProjectVersion.txt" ] && { found="$d"; break; }; d=$(dirname "$d"); done
[ -z "$found" ] && exit 0
INPUT=$(cat 2>/dev/null || true); [ -z "$INPUT" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
CMD=$(printf '%s' "$INPUT"  | jq -r '.tool_input.command // empty')
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
P=""
case "$TOOL" in
  Bash) printf '%s' "$CMD" | grep -qE 'unity[[:space:]]+close|unity[[:space:]]+projects[[:space:]]+clean|editors[[:space:]]+prune.*--remove|self-(update|uninstall)|--allow-install|(^|[[:space:]])--(yes|force)([[:space:]]|$)|pkill[[:space:]]+-f[[:space:]]+Unity|killall[[:space:]]+Unity' && P="destructive-cli" ;;
  Write|Edit) printf '%s' "$FILE" | grep -qE '\.(unity|prefab|asset)$' && P="serialized-asset-write" ;;
esac
[ -z "$P" ] && exit 0
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/unity-ops"; mkdir -p "$STATE"
jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg tool "$TOOL" --arg p "$P" --arg cmd "$CMD" --arg file "$FILE" --arg proj "$found" \
  '{ts:$ts,tool:$tool,pattern:$p,command:$cmd,file:$file,project:$proj,decision:"log"}' >> "$STATE/decisions.jsonl" 2>/dev/null || true
# Advisory: tell the model the guardrail fired, still allow.
jq -cn --arg p "$P" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:("unity-ops guardrail fired: " + $p + ". Advisory in v1 — confirm the preflight/save/confirmation the matching unity-ops skill requires before proceeding.")}}'
exit 0
```

**Promotion of one pattern to a hard gate** (the "one-line edit" the design promises): replace the final `jq` with, for that pattern only,
`jq -cn '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"unity-ops: unity close discards unsaved work; save first or confirm discard"}}'`.

## Consequences for the design
- Advisory mode is real: `additionalContext` reaches the model. Hard gate is real: `deny`. Both live in one script; promotion is per-pattern.
- The JSONL log **is** the DX-metric collector (destructive-command attempts, serialized-asset writes, with project and timestamp).
- Because hooks fire in subagents, RED/GREEN scenario runs will also be logged — the log distinguishes nothing about intent, so scenario runs must be tagged (e.g. `UNITY_OPS_SCENARIO=<name>` in the subagent's env, read by the hook into the record).
- The hook must be tested by `evals/hook-injection.test.sh` in the marketplace CI (it exists on origin/main) — check what it asserts before shipping.
