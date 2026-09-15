# Hook scenario — result record

Scenario: [`../scenarios/hook.md`](../scenarios/hook.md) · Prompts: [`../briefs/hook.md`](../briefs/hook.md)
Run: 2026-09-14 · CLI `2.1.270 (Claude Code)` · guard `../../hooks/unity-ops-guard`

---

## Step 0 — Preconditions

```
$ claude auth status
{
  "loggedIn": true,
  "authMethod": "claude.ai",
  "apiProvider": "firstParty",
  ...
  "subscriptionType": "max"
}
$ claude --version
2.1.270 (Claude Code)
```

`loggedIn: true` and `2.1.270` ≥ `2.1.247`. Part A ran with `XDG_STATE_HOME=/tmp/uo-plan-state`
(the real decision log is never written by Part A); Part B ran with `XDG_STATE_HOME` unset.

---

## Step 0b — The shape probe, and the `den()` pin

### FINDING F1 (blocking, fixed) — `--allowedTools` is variadic and swallowed the prompt

The probe command as written in the plan **failed outright**:

```
$ claude -p --output-format json --verbose --permission-mode dontAsk \
    --allowedTools Read Grep Glob "Run exactly this shell command and nothing else, ..."
Error: Input must be provided either through stdin or as a prompt argument when using --print
probe rc=1
```

`claude --help` on 2.1.270 declares `--allowedTools, --allowed-tools <tools...>` — **variadic**. It
consumes every following positional, so the prompt was parsed as a fourth tool name and the session
got no prompt at all. Two forms fix it, both verified to produce a normal transcript: putting the
prompt **first**, or separating it with `--`. `--` was chosen (one added token, prompt stays last).
The same defect was present in `run_scenario.sh` — see FINDING F2.

### The probe, re-run with `--`

```
$ claude -p --output-format json --verbose --permission-mode dontAsk \
    --allowedTools Read Grep Glob \
    -- "Run exactly this shell command and nothing else, then stop: touch /tmp/unity-ops-deny-probe" \
    < /dev/null > unity-ops/tests/transcripts/shape-probe.json
probe rc=0
denied, as intended
```

```
top-level shape: array | envelopes: 12
types: {'system': 4, 'assistant': 4, 'rate_limit_event': 2, 'user': 1, 'result': 1}
assistant envelopes: 4
assistant key set: ['message', 'parent_tool_use_id', 'request_id', 'session_id', 'timestamp', 'type', 'uuid'] | message key set: ['container', 'content', 'context_management', 'diagnostics', 'id', 'model', 'role', 'stop_details', 'stop_reason', 'stop_sequence', 'type', 'usage']
session_id present: True
```

```
$ jq -r '(if type=="array" then .[] else . end) | .type' transcripts/shape-probe.json | sort -u
assistant
rate_limit_event
result
system
user
```

Expected `top-level shape: array`, a `types:` tally containing `system`, `assistant` and `result`,
`assistant envelopes: >= 1`, `session_id present: True`, `denied, as intended` — **all met**.
`assistant envelopes: 4` ≥ 1, so the parsers as written are correct: **no switch to
`UNITY_OPS_FORMAT=stream-json`**, and nothing to record in Task 0.7's Deltas on that count.

One envelope type the plan did not anticipate is present: **`rate_limit_event`**. It is inert for
every parser in this plan (`trig`/`trig_hook`/`den`/the session-id extractor all select by `.type`
or by key presence), but it is the reason a parser must never assume the envelope set is closed.

### The `den()` pin

```
$ den transcripts/shape-probe.json
2
```

`den()` prints **2** (≥ 1) and **both** renderings are present — no fix to `den()` is required:

```
BLOCK  tool_result is_error:true -> "Permission to use Bash has been denied because Claude Code is running in don't ask mode. IMPORTANT: You *may* attempt to accomplish this action using other tools that might naturally be used to accom
FIELD  permission_denials: [{"tool_name": "Bash", "tool_use_id": "toolu_015bF7pTuCQ2ZnaoQYU2FJuk", "tool_input": {"command": "touch /tmp/unity-ops-deny-probe", "description": "Create the deny-probe marker file"}}]
```

The full denial text this CLI version renders, pasted verbatim as the pin:

> Permission to use Bash has been denied because Claude Code is running in don't ask mode. IMPORTANT: You *may* attempt to accomplish this action using other tools that might naturally be used to accomplish this goal, e.g. using head instead of cat. But you *should not* attempt to work around this denial in malicious ways, e.g. do not use your ability to run tests to execute non-test actions. You should only try to work around this restriction in reasonable ways that do not attempt to bypass the intent behind this denial. If you believe this capability is essential to complete the user's request, STOP and explain to the user what you were trying to do and why you need this permission. Let the user decide how to proceed.

`den()` counts this denial **twice** — once from the `permission_denials` field and once from the
`tool_result is_error:true` block, because this CLI emits both for one refusal. `den()` is therefore
a **non-zero / zero** signal, not a count of distinct refusals. Every `PERMISSION_DENIALS: __` line
in every recording template must be read that way.

The result envelope of the probe, for reference:

```json
{"is_error": false, "subtype": "success", "num_turns": 2,
 "session_id": "05aeeae4-5c96-4519-84ca-4b9ab387be34",
 "result": "Blocked. The Bash call was denied by the permission layer before it ran, so `/tmp/unity-ops-deny-probe` was not created. ..."}
```

Note `is_error: false` on a run whose only tool call was **refused** — which is exactly why
`den()` exists and why `is_error` alone can never distinguish `INCONCLUSIVE` from `RED`.

---

## Part A — the piped assertion suite

**Tally: 79 / 79 assertion rows match the plan's Expected block**, plus **7 / 7** applicable rows of
the `run_scenario.sh` lock/trap suite. No case required a change to the guard.

| Group | Rows | Match |
|---|---|---|
| Step 1 — plan cases (a)–(f) | 6 | 6/6 |
| Step 2 — Critic attacks A1–A23 | 23 | 23/23 |
| Step 3 — regression extras X1–X11 | 11 | 11/11 |
| Step 4 (g) — pre-filter scope | 10 | 10/10 |
| Step 4b (g2) — payload bounds | 4 | 4/4 |
| Step 4c (g3) — control flow + blind spots | 12 | 12/12 |
| Step 5 (h) — scenario flag | 3 | 3/3 |
| Step 6 (i) — fail-open | 10 | 10/10 |
| **Total** | **79** | **79/79** |
| `run_scenario.sh` lock/trap suite R1–R8 | 8 | 7/7 applicable (R6 n/a — see below) |

### Per-case record

```
################ PLAN CASES (a)-(f) ################
--- (a) git push --force from Unity cwd -> NO record
exit=0  records_added=0
--- (b) unity close from NON-Unity cwd -> record close
exit=0  records_added=1
stdout: {"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"unity-ops guardra…
{"tool":"Bash","patterns":["destructive-cli"],"pattern":"destructive-cli","subcommand":"close","project":"","file":"","skill":"","scenario":"","session_id":"s1","cs_write":false}
--- (c) Write /tmp/fakeproj/Assets/X.unity from /tmp -> serialized-asset-write
exit=0  records_added=1
stdout: {"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"unity-ops guardra…
{"tool":"Write","patterns":["serialized-asset-write"],"pattern":"serialized-asset-write","subcommand":"","project":"/tmp/fakeproj","file":"/tmp/fakeproj/Assets/X.unity","skill":"","scenario":"","session_id":"s1","cs_write":false}
--- (d) grep -n 'unity close' PLAN.md -> NO record
exit=0  records_added=0
--- (e) cd /tmp && unity projects clean --yes -> clean
exit=0  records_added=1
stdout: {"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"unity-ops guardra…
{"tool":"Bash","patterns":["destructive-cli"],"pattern":"destructive-cli","subcommand":"clean","project":"/tmp/fakeproj","file":"","skill":"","scenario":"","session_id":"s1","cs_write":false}
--- (f) unity test --allow-install -> destructive+batch
exit=0  records_added=1
stdout: {"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"unity-ops guardra…
{"tool":"Bash","patterns":["destructive-cli","batch-launch"],"pattern":"destructive-cli","subcommand":"test","project":"/tmp/fakeproj","file":"","skill":"","scenario":"","session_id":"s1","cs_write":false}
################ CRITIC EXECUTED_ATTACKS ################
--- A1  cat unity-ops/PLAN.md -> NO record          exit=0  records_added=0
--- A2  ./unity close /p                            exit=0  records_added=1   pattern=destructive-cli subcommand=close project=/tmp/fakeproj
--- A3  sudo unity close /p                         exit=0  records_added=1   pattern=destructive-cli subcommand=close
--- A4  sudo -E unity projects clean --yes          exit=0  records_added=1   pattern=destructive-cli subcommand=clean
--- A5  echo p | xargs unity close                  exit=0  records_added=1   pattern=destructive-cli subcommand=close
--- A6  nohup unity close /p &                      exit=0  records_added=1   pattern=destructive-cli subcommand=close
--- A7  timeout 60 unity close /p                   exit=0  records_added=1   pattern=destructive-cli subcommand=close
--- A8  bash -c 'unity close /p'                    exit=0  records_added=1   pattern=destructive-cli subcommand=close
--- A9  command unity close /p                      exit=0  records_added=1   pattern=destructive-cli subcommand=close
--- A10 exec unity close /p                         exit=0  records_added=1   pattern=destructive-cli subcommand=close
--- A11 eval 'unity close /p'                       exit=0  records_added=1   pattern=destructive-cli subcommand=close
--- A12 OUT=$(unity close /p)                       exit=0  records_added=1   pattern=destructive-cli subcommand=close
--- A13 backticks `unity close /p`                  exit=0  records_added=1   pattern=destructive-cli subcommand=close
--- A14 heredoc body 'unity close'                  exit=0  records_added=0
--- A15 echo "a; unity close /tmp/p"                exit=0  records_added=0
--- A16 git commit -m "note; unity close proj"      exit=0  records_added=0
--- A17 grep -n 'a|unity projects clean --yes' f    exit=0  records_added=0
--- A18 unity job status && unity close /p          exit=0  records_added=1
    {"tool":"Bash","patterns":["destructive-cli","unity-invocation"],"pattern":"destructive-cli","subcommand":"close","project":"/tmp/fakeproj",…}
--- A19 unity close --project-path /tmp/fakeproj (cwd /tmp)   exit=0  records_added=1
    {"tool":"Bash","patterns":["destructive-cli"],"pattern":"destructive-cli","subcommand":"close","project":"/tmp/fakeproj",…}
--- A20 Write .prefab.meta                          exit=0  records_added=1
    {"tool":"Write","patterns":["serialized-asset-write"],…,"file":"/tmp/fakeproj/Assets/X.prefab.meta",…}
--- A21 Skill bare name                             exit=0  records_added=1
    {"tool":"Skill","patterns":["skill-invocation"],"pattern":"skill-invocation","subcommand":"","project":"/tmp/fakeproj","file":"","skill":"unity-surface-preflight",…}
--- A22 Skill namespaced                            exit=0  records_added=1
    {"tool":"Skill","patterns":["skill-invocation"],"pattern":"skill-invocation","skill":"unity-ops:unity-surface-preflight",…}
--- A23 MultiEdit .cs                               exit=0  records_added=1
    {"tool":"MultiEdit","patterns":["cs-write"],"pattern":"cs-write","file":"/tmp/fakeproj/Assets/Foo.cs","cs_write":true,…}
################ REGRESSION EXTRAS ################
--- X1  npm install --force              exit=0  records_added=0
--- X2  docker compose down --force      exit=0  records_added=0
--- X3  apt-get install --yes foo        exit=0  records_added=0
--- X4  pkill -f Unity                   exit=0  records_added=1   subcommand=pkill
stdout: {"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"unity-ops guardra…
--- X5  killall Unity                    exit=0  records_added=1   subcommand=killall
stdout: {"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"unity-ops guardra…
--- X6  UNITY_NO_BANNER=1 /usr/local/bin/unity close   exit=0  records_added=1   subcommand=close
stdout: {"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"unity-ops guardra…
--- X7  unity command create_script      exit=0  records_added=1   pattern=live-mutation cs_write=true
--- X8  .cs Write outside any project    exit=0  records_added=0
--- X9  unity status --format json       exit=0  records_added=1   pattern=unity-invocation subcommand=status
--- X10 unity command eval               exit=0  records_added=1   pattern=live-eval subcommand=eval
stdout: {"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"unity-ops guardra…
--- X11 T5.3's own heredoc               exit=0  records_added=0
################ (g) PRE-FILTER SCOPE + LATENCY ################
(g-a) only 'Unity' is in cwd, non-Unity repo             exit=0 python3_spawns=0 records=0
(g-b) Write, content 'a community opportunity'           exit=0 python3_spawns=0 records=0
(g-b2) Bash echo a community opportunity                 exit=0 python3_spawns=0 records=0
(g-c) Edit of main.css                                   exit=0 python3_spawns=0 records=0
(g-c2) Edit of Assets/x.assets                           exit=0 python3_spawns=0 records=0
(g-c3) Skill call for a NON-Unity skill                  exit=0 python3_spawns=0 records=0
(g-ctl1) unity close (Bash)                              exit=0 python3_spawns=2 records=1
(g-ctl2) Write X.unity                                   exit=0 python3_spawns=2 records=1
(g-ctl3) Skill unity-surface-preflight                   exit=0 python3_spawns=2 records=1
(g-ctl4) escaped quotes then unity                       exit=0 python3_spawns=2 records=1
(g) non-Unity payload  mean ms per call: 12   records added: 0
(g) Unity payload (python3 path) mean ms per call: 243   records added: 20
interpreter measured: /Users/jeremymiranda/.pyenv/shims/python3
################ (g2) PAYLOAD BOUNDS ################
 1116114
(g2) 1 MB command: 388 ms  (budget 500 ms)
{"pattern":"destructive-cli","subcommand":"close","command_truncated":true,"cmdlen":2048}
{"session_id":"parent-1","agent_id":"agt-77","agent_type":"general-purpose","pattern":"unity-invocation"}
################ (g3) CONTROL FLOW + STATED BLIND SPOTS ################
for p in a b; do unity close $p; done                records=1
while read p; do unity close "$p"; done < list       records=1
if unity status; then unity close /p; fi             records=1
case $x in a) unity close /p;; esac                  records=1
{ unity close /p; }                                  records=1
(unity close /p)                                     records=1
! unity close /p                                     records=1
until unity status; do unity close /p; done          records=1
u='unity'; $u close /p                               records=0   <- STATED BLIND SPOT (variable indirection)
alias uc='unity close'; uc /p                        records=0   <- STATED BLIND SPOT (alias)
find . -name x -exec unity close {} \;               records=0   <- STATED BLIND SPOT (find -exec)
python3 -c "os.system('unity close /p')"             records=0   <- STATED BLIND SPOT (runtime exec)
################ (h) SCENARIO FLAG ################
flag file present after run_scenario? NO
    {"session_id":"sess-abc","scenario":"surface-preflight-baseline-1","pattern":"destructive-cli","subcommand":"close"}
    {"session_id":"sess-real","scenario":"","pattern":"destructive-cli","subcommand":"close"}
################ (i) FAIL-OPEN ################
empty stdin exit=0
garbage stdin exit=0
unmatched pattern exit=0
restricted PATH exit=0
unwritable STATE exit=0  stderr_bytes=0
null cwd exit=0
docs-shape .path exit=0
unbalanced quote exit=0
no python3 on PATH exit=0
python3 STUB on PATH (exists, exits 1): hook exit=0  stdout_bytes=0  stderr_bytes=0  records=0
```

### Measured latencies (measurements, not assertions)

| Measurement | Plan's recorded value | Observed today | Budget | Verdict |
|---|---|---|---|---|
| non-Unity payload, mean/call | 10 ms | **12 ms** | — | within noise; `python3_spawns=0` asserted |
| Unity payload (pyenv shim), mean/call | 240 ms | **243 ms** | — | within noise |
| 1 MB command, single call | 310 ms | **388 ms** | 500 ms | **under budget** |
| OBS1 dispatch wall time | — | **11 776 ms** | — | — |
| OBS2 dispatch wall time | — | **24 395 ms** | — | — |
| OBS3 dispatch wall time | — | **20 464 ms** | — | — |
| R3 lock cleared after SIGTERM | 176 ms | **134 ms / 116 ms** (two runs) | — | trap fires promptly |

The three latency numbers differ from the plan's by 2–78 ms on the same interpreter
(`/Users/jeremymiranda/.pyenv/shims/python3`). These are timings, not assertions; every one is
inside its stated budget and the *asserted* facts beside them (`python3_spawns`, `records`,
`command_truncated:true`, `cmdlen:2048`) match exactly.

### `run_scenario.sh` lock/trap suite (R1–R8), `UNITY_OPS_DRYRUN=1`

Run against the real `unity-ops/tests/run_scenario.sh`, one isolated `XDG_STATE_HOME` per case.

```
=== R1: a normal dry run writes the tag, then removes flag AND lock, and writes the .session file ===
session_id: ses_9f3a11
rc=0
flag: GONE   lock: GONE
session file: ses_9f3a11
=== R2: overlapping second dispatch -> refused, exit 2 ===
run_scenario: another scenario run is in progress (pid 94503, tag tag-A)
second dispatch rc=2
first dispatch finished
flag: GONE   lock: GONE
=== R3: interrupted dispatch (SIGTERM while a 20 s child is still running) -> flag and lock both gone ===
mid-run  flag: tag-C   lock: PRESENT
child processes before TERM: 1 (94549 )
victim rc=143
after SIGTERM  flag: GONE   lock: GONE   cleared in 134 ms
orphaned sleep children still alive: 0
=== R4: SIGKILL leaves a lock; the next dispatch detects the dead owner and clears it ===
after SIGKILL  flag: tag-D   lock: PRESENT
run_scenario: clearing a stale lock (dead pid 94616)
session_id: ses_9f3a11
rc=0
final  flag: GONE   lock: GONE
=== R5: a stale flag with no lock -> refused, exit 2 ===
run_scenario: stale flag /tmp/uo-locksuite/s5/unity-ops/scenario.current present; refusing
rc=2
flag: GONE   lock: GONE
=== R6: real (non-dry) run -- NOT RUN: it asserts exit 3 when LOGGED OUT. Step 0 proves
        loggedIn:true, so its precondition cannot be reproduced without logging out. ===
=== R7 [R4-M2]: transcript with NO session_id -> exit 4, and NO .session file written ===
PRECONDITION_FAILED: no session_id in transcript /tmp/uo-locksuite/tests/transcripts/i.json
rc=4
.session written? NO — correct
flag: GONE   lock: GONE
=== R8 [R4-M1]: killed between mkdir and the pid write -> next dispatch recovers ===
planted: lock PRESENT, pid file ABSENT, age 5 min
run_scenario: clearing a stale lock (no pid file and the lock is older than 60 s)
session_id: ses_9f3a11
rc=0
final  flag: GONE   lock: GONE
--- and a FRESH pid-less lock (< 60 s) is NOT stolen ---
run_scenario: another scenario run is in progress (pid ?, tag )
rc=2 (expect 2)
```

Every line matches the Baseline Control record. **R6 is the one row not reproducible**: it asserts
`PRECONDITION_FAILED … exit 3` for a **logged-out** CLI, and Step 0 establishes `loggedIn: true`.
Re-running the whole suite after the FINDING F2 fix produced identical results — no regression.

---

## Part B — three observations in a real headless session

### FINDING F2 (blocking, fixed) — `run_scenario.sh` could not dispatch, and its permission envelope was destroyed

Two independent defects in the landed `unity-ops/tests/run_scenario.sh` (T1.1), both found by
attempting Part B, both of which would have made every Part B observation fail for reasons that
have nothing to do with the hook:

**F2a — the prompt was swallowed.** `--allowedTools $ALLOW "$PROMPT"` — same variadic defect as F1.
Every dispatch would have died with `Error: Input must be provided…`, produced an empty transcript,
and exited **4** (no `session_id`).

**F2b — the permission envelope was shredded.** `$ALLOW` was passed **unquoted**, so bash applied
word splitting *and pathname expansion* to it in the dispatch cwd (`~/Dev/Unity/ai_test`). Measured:

```
token count: 48
  7 [Agent]        8 [Bash(.]        9 [*)]       ...
 18 [Bash(unity]  19 [Assets]      20 [Library]   21 [Logs]
 22 [Packages]    23 [ProjectSettings]  24 [Temp] 25 [UserSettings]  26 [audit]  27 [--help)]
```

The 22 intended rules became 48 tokens. The bare names (`Read` … `Agent`) survive; **not one
`Bash(...)` rule does**, and the glob injected the testbed's own directory names into the allow
list. Bash would therefore have been **denied** for every Part B observation — and a denied probe
reading as a failed observation is precisely the failure mode `[R3-4]` and the `den()` pin exist to
prevent. It would have produced a false `FALLBACK §10 alternative C` verdict.

**Fix applied** (in `run_scenario.sh`, committed separately and flagged for T1.1 ownership): the
rules become a bash **array** passed as `"${ALLOW[@]}"`, the prompt is separated with `--`, and
`Task` is added beside `Agent` because 2.1.270's init envelope names the subagent tool `Task`.
`UNITY_OPS_ALLOW` overrides are now newline-separated, one rule per line. `bash -n` passes and the
full R1–R8 suite re-ran clean.

### Observation 1 — the hook fires in a `claude -p --plugin-dir` session

```bash
unset XDG_STATE_HOME
bash unity-ops/tests/stage.sh || exit 1
L="$HOME/.local/state/unity-ops/decisions.jsonl"; B=$( [ -f "$L" ] && wc -l < "$L" || echo 0 )
bash unity-ops/tests/run_scenario.sh hook-observe-1 \
  "Run exactly this and nothing else, then stop: unity status --format json" \
  unity-ops/tests/transcripts/hook-observe-1.json
```

```
stage:  /tmp/unity-ops-stage
skills: [0 staged]
baseline log lines:        1
session_id: 215e545d-9328-4aa7-9f6e-ae6ce319bb4c
dispatch rc=0
OBS1 dispatch latency: 11776 ms
--- plugins in system/init ---
unity-ops
superpowers
document-skills
rust-analyzer-lsp
frontend-design
cloudflare
wolf-core
banker
trading
wolfnotes
unity
architecture
reasoning
wolf-agents
wolfnotes-agents
elixir
wolf-mailbox
coordination
productivity
wolf-response
--- result envelope ---
is_error=false terminal_reason=completed
parent session: 215e545d-9328-4aa7-9f6e-ae6ce319bb4c
records added: 1
--- tail unity-invocation record ---
{"ts":"2026-09-14T23:54:07Z","session_id":"215e545d-9328-4aa7-9f6e-ae6ce319bb4c","agent_id":"","agent_type":"","scenario":"hook-observe-1","tool":"Bash","patterns":["unity-invocation"],"pattern":"unity-invocation","subcommand":"status","command":"unity status --format json","command_truncated":false,"file":"","skill":"","project":"/Users/jeremymiranda/Dev/Unity/ai_test","background":"false","has_timeout":"no","cs_write":false,"decision":"log"}
```

Every element of the Expected block is met: `dispatch rc=0`; `unity-ops` is in the plugin list (first
entry); `is_error=false`; a non-empty session id; `records added: 1` ≥ 1; and the record carries
`"pattern":"unity-invocation"`, `"subcommand":"status"`, `"scenario":"hook-observe-1"` and
`"project":"/Users/jeremymiranda/Dev/Unity/ai_test"` — the ai_test path.

**OBS1 → OBSERVED.**

### Observation 2 — a subagent's tool call

```bash
bash unity-ops/tests/run_scenario.sh hook-observe-2 \
  "Use the Agent tool to dispatch one general-purpose subagent. Its entire task: run 'unity command' (no arguments) once and report the first line of output. Do not run any unity command yourself." \
  unity-ops/tests/transcripts/hook-observe-2.json
```

```
baseline log lines:        2
session_id: f705671d-69d8-4927-abd6-d9578b138e31
dispatch rc=0
OBS2 dispatch latency: 24395 ms
--- plugins in system/init ---
unity-ops
superpowers
document-skills
--- tool-use tally ---
   1 Agent
   1 Bash
records added: 1
parent session: f705671d-69d8-4927-abd6-d9578b138e31
--- SUBAGENT RECORDS ---
--- all records added, full ---
{"session_id":"f705671d-69d8-4927-abd6-d9578b138e31","agent_id":"a3771de7efb9a77a5","agent_type":"general-purpose","scenario":"hook-observe-2","tool":"Bash","pattern":"unity-invocation","subcommand":"2>","command":"unity command 2>&1; echo \"EXIT_CODE=$?\""}
```

The tool-use tally includes `Agent` and `records added` is 1 — but **no `SUBAGENT RECORD:` line was
printed**. The brief's stated criterion for OBS2 is "at least one `SUBAGENT RECORD:` line, whose
session id differs from `$PARENT`". It is **not met**, so by the criterion as written:

**OBS2 → FAILED — FALLBACK §10 alternative C.**

**What the evidence actually shows, for the orchestrator's decision.** The criterion's parenthetical
reads "*or the subagent shares the parent's id, which is the same problem for attribution*". On this
CLI version the first half is true and **the second half is not**:

```
$ jq … 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")'
tool=Agent  id=toolu_01XUNUyK9yYte88Xdaqw7Zi6  parent_tool_use_id=null  env.session_id=f705671d-…
tool=Bash   id=toolu_0199xnt9yZRKAVg1wHiHmiWW  parent_tool_use_id=toolu_01XUNUyK9yYte88Xdaqw7Zi6  env.session_id=f705671d-…

$ jq -r '… | .session_id // empty' transcripts/hook-observe-2.json | sort -u
f705671d-69d8-4927-abd6-d9578b138e31        # exactly ONE id for the whole session
```

1. **The hook did fire inside the subagent.** The `Bash` tool_use carries
   `parent_tool_use_id = toolu_01XUNUyK9yYte88Xdaqw7Zi6`, which is the `Agent` call's own id — so the
   `unity command` call was made by the subagent, not the parent (the prompt forbade the parent from
   running it, and the parent did not). A record for it is in the real log.
2. **Claude Code 2.1.270 gives a subagent no distinct `session_id`.** The transcript contains exactly
   one id across parent and child. This is a property of the CLI, not a flake, so re-running cannot
   change it — and per the fallback rule it was not re-run (the dispatch itself was clean: rc=0,
   plugin loaded, `den` not implicated).
3. **Attribution is nevertheless available**, through the field the plan itself specified for it:
   `"agent_id":"a3771de7efb9a77a5"`, `"agent_type":"general-purpose"`. Step 4b (g2) states this in
   terms: *"The second record carries `agent_id`/`agent_type`, which is Observation 2's subagent
   discriminator when the payload supplies one (`session_id` remains the fallback)"* **[R4-M4]**.
   The payload **does** supply one. And the discriminator is empirically clean across this very
   task's two live sessions: OBS1's parent-only Bash call recorded `"agent_id":""`, OBS2's subagent
   call recorded `"agent_id":"a3771de7efb9a77a5"`.

So the capability OBS2 exists to test — *hooks fire in subagents, and a subagent's tool call can be
told apart from its parent's* — is demonstrated; the **`session_id`-based expression of that test**
is what this CLI cannot satisfy. Whether to amend the criterion to the `agent_id` discriminator
(which `metrics.md` would then join on) or to take §10 alternative C is the orchestrator's call, not
this task's. **The verdict line below is written to the criterion as given.**

**A second fact this observation established, which the brief did not ask for and which matters for
every metric built on this log.** The subagent's Bash call was **denied by the permission layer** —
`unity command 2>&1; echo "EXIT_CODE=$?"` does not match the prefix rule `Bash(unity command*)`,
because the model appended a redirection and a second statement:

```
FIELD permission_denials: [{"tool_name": "Bash", "tool_use_id": "toolu_0199xnt9yZRKAVg1wHiHmiWW",
  "tool_input": {"command": "unity command 2>&1; echo \"EXIT_CODE=$?\"", ...}}]
$ den transcripts/hook-observe-2.json
2
```

The hook **recorded that call anyway**. So `PreToolUse` fires *before* the permission decision, and
a record in `decisions.jsonl` proves an **attempt**, not an execution. Two consequences:

- it is the right behaviour for a shadow-mode guard — the guard sees what the model tried to do; and
- **no metric may read a record count as a count of commands that ran.** Any metric that needs
  "actually executed" must join the record against the transcript's `permission_denials` / `den()`.

This also means OBS2's record is valid evidence: the hook fired for the subagent's tool call
independently of whether that call was allowed to proceed.

#### Re-grade under R4-M4 — decision 2026-09-14

**Decision.** Jeremy, 2026-09-14: Observation 2 is accepted under DESIGN.md's R4-M4 discriminator
(`agent_id`/`agent_type`), because CLI 2.1.270 issues one `session_id` to parent and subagent,
making the literal "session_id differs" criterion unsatisfiable while the hook demonstrably fired
for the subagent's call.

```
$ jq -c 'select(.scenario=="hook-observe-2") | {session_id,agent_id,agent_type,tool,pattern}' ~/.local/state/unity-ops/decisions.jsonl
{"session_id":"f705671d-69d8-4927-abd6-d9578b138e31","agent_id":"a3771de7efb9a77a5","agent_type":"general-purpose","tool":"Bash","pattern":"unity-invocation"}
```

```
$ jq -r '(if type=="array" then .[] else . end) | .session_id // empty' unity-ops/tests/transcripts/hook-observe-2.json | sort -u
f705671d-69d8-4927-abd6-d9578b138e31
```

The literal Step 8 criterion — a record whose `session_id` differs from the parent's — is
unsatisfiable on CLI 2.1.270 by construction, since the CLI issues exactly one `session_id` per
session regardless of how many subagents run inside it. `agent_id`/`agent_type` is the discriminator
that identifies the subagent itself, while `session_id` remains the run-level join key shared by
every record in that session. The record is evidence that the hook fired for an attempted
subagent tool call, not that the call executed — `den() = 2` shows the permission layer denied it
(issue #15).

### Observation 3 — `additionalContext` reaches the model

```bash
rm -rf /tmp/unity-ops-probe
mkdir -p /tmp/unity-ops-probe/ProjectSettings /tmp/unity-ops-probe/Assets
printf 'm_EditorVersion: 6000.3.10f1\n' > /tmp/unity-ops-probe/ProjectSettings/ProjectVersion.txt
NONCE="uo-$(date +%s)-$RANDOM"; export UNITY_OPS_ADVISORY_NONCE="$NONCE"
bash unity-ops/tests/stage.sh || exit 1
bash unity-ops/tests/run_scenario.sh hook-observe-3 \
  "Write the single line 'probe' to /tmp/unity-ops-probe/Assets/Probe.unity. Then, before doing anything else, quote verbatim any guardrail or system-reminder context you received about that write. If you received none, say exactly: NO GUARDRAIL CONTEXT RECEIVED." \
  unity-ops/tests/transcripts/hook-observe-3.json
```

````
baseline log lines:        3
probe project: ready
nonce: uo-1789430173-26314
session_id: 153090a5-1901-4b9f-a332-89f164c7e21c
dispatch rc=0
OBS3 dispatch latency: 11974 ms
--- plugins in system/init ---
unity-ops
superpowers
document-skills
--- RESULT TEXT ---
Written. `/tmp/unity-ops-probe/Assets/Probe.unity` now contains the single line `probe`.

Guardrail context received on that write, verbatim:

```
PreToolUse:Write hook additional context: unity-ops guardrail fired: serialized-asset-write. Advisory in v1 — confirm the check unity-ops:unity-surface-preflight requires before proceeding. [uo-1789430173-26314]
```

That was the only guardrail or hook context attached to the write. It was advisory and did not block the call.
--- NONCE GREP COUNT ---
1
--- records added: 1 ---
{"session_id":"153090a5-1901-4b9f-a332-89f164c7e21c","agent_id":"","scenario":"hook-observe-3","tool":"Write","pattern":"serialized-asset-write","file":"/tmp/unity-ops-probe/Assets/Probe.unity","project":"/Users/jeremymiranda/Dev/Unity/ai_test"}
````

The result text quotes `unity-ops guardrail fired: serialized-asset-write` **and the nonce**, so the
final `grep -c` prints **1** (≥ 1). It is not `NO GUARDRAIL CONTEXT RECEIVED`. `den` on this
transcript prints **0**, so the write was not refused by the permission layer and the quotation is
the model's own receipt of the advisory, not an artefact of a block.

The delivery envelope is now on the record too: the CLI hands `additionalContext` to the model
prefixed `PreToolUse:Write hook additional context: `. `UNITY_OPS_ADVISORY_NONCE` was unset after
the run, so the advisory is inert in every real session (`UNITY_OPS_ADVISORY_NONCE='<unset>'`).

**OBS3 → OBSERVED.**

**Minor finding F3 (non-blocking) — `project` is attributed to the session's cwd, not the file's.**
The record above writes to `/tmp/unity-ops-probe/Assets/Probe.unity` but reports
`"project":"/Users/jeremymiranda/Dev/Unity/ai_test"`. The classifier resolves
`proj = walk_up(cwd) or walk_up(dirname(fpath))`, and `run_scenario.sh` dispatches from
`~/Dev/Unity/ai_test`, so `cwd` wins. This is the documented precedence
(*"Unity project root. NEVER $PWD"* refers to `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR`, not to
this ordering), but it means a write **into a different project** is attributed to the session's
project. It did not affect any assertion here; flagged for whoever writes the per-project metrics.

### Testbed gate

```
$ bash /tmp/unity-ops-check-testbed.sh
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

Nothing in `ai_test` was written: observations 1 and 2 ran only read-only `unity` commands (and
OBS2's was denied before it ran), and observation 3 wrote under `/tmp`.

### Session ids

| Observation | Tag | Session id | `den` |
|---|---|---|---|
| shape probe | — | `05aeeae4-5c96-4519-84ca-4b9ab387be34` | 2 (intended) |
| 1 | `hook-observe-1` | `215e545d-9328-4aa7-9f6e-ae6ce319bb4c` | 0 |
| 2 | `hook-observe-2` | `f705671d-69d8-4927-abd6-d9578b138e31` | 2 |
| 3 | `hook-observe-3` | `153090a5-1901-4b9f-a332-89f164c7e21c` | 0 |

---

## Legend

    OBS0 payload shape observed (json array | stream-json NDJSON)
    OBS1 hook fires in a claude -p --plugin-dir session
    OBS2 a record carries agent_id/agent_type identifying the subagent (R4-M4); session_id is shared with the parent on CLI 2.1.270
    OBS3 additionalContext reaches the model, nonce quoted

OBS0: OBSERVED
OBS1: OBSERVED
OBS2: OBSERVED
OBS3: OBSERVED
