# The MCP surface is out of scope, on purpose

`unity mcp configure <client>` exists on this binary and is documented in the installed skill at
`references/integration-advanced.md:50-85`. It registers Unity's Model Context Protocol server — a
different integration path from the one these skills are about: it hands an AI client a set of *tools*,
where `unity skill install` hands it *docs*.

`unity-ops` deliberately does not wrap it, own it, or trigger on it (decision D2):

- No `unity-ops` skill description mentions it, so none of them compete for a request about it.
- No `unity-ops` guardrail, hook pattern, or gate matches `unity mcp` or any of its subcommands.
- Nothing here restates its options, its client list, or its config file locations.

If you want that server configured, follow the installed `unity-cli` skill's
`references/integration-advanced.md` and run its commands directly. Everything in `unity-ops` assumes the
plain CLI invocation path described in `../SKILL.md`, and stays correct whether or not that server is
configured.

This file is the only place in `unity-ops` that describes the feature at all. That is intentional: keeping
the token out of every skill description is what stops these skills from being routed to a request they
have nothing to say about.
