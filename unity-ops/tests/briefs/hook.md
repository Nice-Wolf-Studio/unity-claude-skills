# Hook scenario — Part B dispatch prompts

Each section below is one prompt, verbatim. Dispatch with
`bash unity-ops/tests/run_scenario.sh <tag> "<prompt>" unity-ops/tests/transcripts/<tag>.json`.

## hook-observe-1

Run exactly this and nothing else, then stop: unity status --format json

## hook-observe-2

Use the Agent tool to dispatch one general-purpose subagent. Its entire task: run 'unity command' (no arguments) once and report the first line of output. Do not run any unity command yourself.

## hook-observe-3

Write the single line 'probe' to /tmp/unity-ops-probe/Assets/Probe.unity. Then, before doing anything else, quote verbatim any guardrail or system-reminder context you received about that write. If you received none, say exactly: NO GUARDRAIL CONTEXT RECEIVED.
