# unity-ops DX metrics — definitions and queries

Log: `${XDG_STATE_HOME:-$HOME/.local/state}/unity-ops/decisions.jsonl`, one JSON object per line, appended by
`hooks/unity-ops-guard`. **Every query filters `scenario == ""`** — hooks fire in subagents, so scenario runs
are in this file too and are excluded by the tag the runner writes into
`${XDG_STATE_HOME:-$HOME/.local/state}/unity-ops/scenario.current` before each dispatch.

    L="${XDG_STATE_HOME:-$HOME/.local/state}/unity-ops/decisions.jsonl"

**Record shape.** `patterns` is an **array** — a command can match more than one pattern
(`unity test --allow-install` is both `batch-launch` and `destructive-cli`), so every query below tests
membership with `index(...)`, never equality against the scalar `pattern`. `pattern` is the first match and
exists only for one-line eyeballing. `subcommand` is the canonical `unity` verb, with the group verbs
(`projects`, `editors`, `plugin`, `pipeline`, `skill`, `vcs`, `command`, `job`, `licenses`, `modules`) taking
their object.

    {"ts":…,"session_id":…,"agent_id":…,"agent_type":…,"scenario":…,"tool":…,"patterns":[…],
     "pattern":…,"subcommand":…,"command":…,"command_truncated":…,"file":…,"skill":…,"project":…,
     "background":…,"has_timeout":…,"cs_write":…,"decision":"log"}

**Two bounded fields, new in revision 5 [R4-M4].** The classifier reads at most the **first 64 KB** of `command`
and stores at most the **first 2 KB** of it, setting `command_truncated:true` when it cut. So `command` is a
**sample, never a reproduction** — no query may reconstruct an invocation from it; the field-keyed queries below
are the ones that hold. `agent_id`/`agent_type` carry the payload's subagent discriminator when the harness
supplies one (empty string otherwise), and `session_id` remains the fallback everywhere.

`pattern` is the **most severe** match, by the fixed order `destructive-cli > live-eval >
serialized-asset-write > cs-write > live-mutation > batch-launch > live-readback >
recompile-confirm > skill-invocation > unity-invocation`, and `subcommand` comes from the segment
that produced it. Revision 3 used first-added, so `unity job status && unity close /p` recorded
`pattern:"unity-invocation"` and metric 4 below did not fire on a real `close`.

`skill` is the raw `input.skill` of a `Skill` tool call (`pattern:"skill-invocation"`), bare or
namespaced as the model wrote it. **This is the trigger signal** — see metric 7.

**The session id is the record of truth; the tag is a convenience.** `run_scenario.sh` writes every
dispatch's own `session_id` to `tests/transcripts/<tag>.session`. Build the exclusion set from **those
files**, not from the log's own tags — a run whose tag was lost still has its `.session` file:

    SCEN_SESSIONS=$(cat unity-ops/tests/transcripts/*.session 2>/dev/null \
                    | tr -d ' \t\r' | grep -v '^$' | sort -u | paste -sd'|' -)
    SCEN_SESSIONS="${SCEN_SESSIONS:-__none__}"
    case "$SCEN_SESSIONS" in ''|'|'*|*'|'|*'||'*)
      echo "REFUSING: SCEN_SESSIONS has an empty alternative — it would match every record" >&2; exit 1 ;;
    esac
    # then, in any query:  select(.scenario=="" and (.session_id|test($SCEN_SESSIONS)|not))

**Build it from NON-EMPTY `.session` files only, and refuse an empty alternative [R4-M2].** One zero-byte or
blank `.session` file makes `paste` produce `|ses_a|ses_b`, and `test("|ses_a|ses_b")` matches **every** string —
so every record in the log is excluded and every metric silently reads zero. Verified: with one blank `.session`
among three, the revision-4 build counted **0** real records where the answer was **2**; the build above counts 2.
`run_scenario.sh` now exits `4` rather than writing an empty `.session`, so the two fixes are belt and braces.

Union it with the log's own tagged sessions as a belt-and-braces second source:

    jq -rs '[.[]|select(.scenario!="")|.session_id]|unique|join("|")' "$L"

| # | Metric | Skill | Query |
|---|---|---|---|
| 7 | Skill triggering — which skill won each moment | all six | see below |
| 1 | Blind-fallback rate | `unity-surface-preflight` | see below |
| 2 | False-"done" rate after live edits | `unity-live-edit-verification` | see below |
| 3 | Minutes-to-verified-change | `unity-script-change-gate` | see below |
| 4 | `close`-without-save incidents / month | `unity-destructive-gate` | see below |
| 5 | Wasted batch launches | `unity-batch-hygiene` | see below |
| 6 | Broken-invocation rate | `unity-cli-contract` | **part manual — see below** |

> **Two jq traps, both hit while writing this file and both fixed above.** `|` binds tighter than `or`, so
> `[.patterns[]|startswith("live-")]|any or (…)` parses as `[…]|(any or …)` and errors with
> *"Cannot index array with string"* — every disjunct needs its own parentheses. And
> `jq -r 'select(…)' "$L" | wc -l` counts the **lines of the pretty-printed objects**, not the records: it
> reported `37` where the answer was `2`. Project a scalar (`| .ts`) before any `wc -l`.

## 1. Blind-fallback rate — serialized-asset writes, and the sessions they happened in
    jq -r 'select(.scenario=="" and (.patterns|index("serialized-asset-write"))) | "\(.ts)  \(.session_id)  \(.file)"' "$L"
    # denominator: sessions that touched Unity at all
    jq -r 'select(.scenario=="") | .session_id' "$L" | sort -u | wc -l
A record here is a **candidate** incident. Whether preflight evidence existed earlier in that session is not in
the log — read the session by id. Target 0 records.

## 2. False-"done" rate — a mutation with no read-back after it in the same session
    jq -rs '[.[] | select(.scenario=="")] | group_by(.session_id)[]
            | {s:.[0].session_id,
               mut:[.[]|select(.patterns|index("live-mutation"))]|length,
               rb:[.[]|select(.patterns|index("live-readback"))]|length}
            | select(.mut>0 and .rb==0) | "\(.s)  mutations=\(.mut)  readbacks=0"' "$L"
Each line is a session that mutated a live Editor and never read back. Target: no lines.

## 3. Minutes-to-verified-change — any cs-write to the next recompile-confirm
    jq -rs '[.[] | select(.scenario=="" and (.cs_write==true or (.patterns|index("recompile-confirm"))))]
            | sort_by(.ts) | . as $a | range(0;length) as $i
            | select($a[$i].cs_write==true)
            | [$a[($i+1):][] | select(.patterns|index("recompile-confirm"))][0] as $c
            | select($c!=null)
            | "\(if $a[$i].file=="" then $a[$i].command else $a[$i].file end)  \(($c.ts|fromdateiso8601) - ($a[$i].ts|fromdateiso8601))s"' "$L"
Keyed on **`cs_write`**, not on `pattern=="cs-write"`: a script authored through the live Editor
(`unity command create_script`) records as `live-mutation` **and** sets `cs_write:true`, and revision 2's
query missed every one of those. A `cs_write` record with no following `recompile-confirm` in the same
session is an unverified change — count those too.

## 4. close-without-save incidents — keyed on FIELDS, never a regex over the command text
    jq -r 'select(.scenario=="" and .tool=="Bash" and .pattern=="destructive-cli" and .subcommand=="close")
           | "\(.ts)  \(.project)  \(.command)"' "$L"

**This exact expression — `tool=="Bash" and pattern=="destructive-cli" and subcommand=="close"` — is
THE tripwire**, and it is the form that goes into Task 9.5's issue body verbatim. `pattern` (most
severe) rather than `patterns|index(...)` because a `close` must be the most severe thing in the
command for this to be a `close` incident; `tool=="Bash"` because a `Skill` or `Write` record can
never be one.
**Any line here fires the decision-Q2 tripwire**: promote `destructive-cli` to `deny` immediately
(DESIGN.md §4A promotion procedure), do not wait for the 30-day window.

> **This query is field-based on purpose.** Revision 2 used `(.command|test("unity[ ]+close"))`, which matched
> `grep -n 'unity close' unity-ops/PLAN.md` and `git commit -m "…unity close…"` — so reading this plan's own
> text would have promoted the pattern to `deny` and blocked `git push --force` in every Unity directory. The
> hook's segment rule means no such record can exist now; the field-based query is the second line of defence.

## 5. Wasted batch launches — no timeout, or foregrounded
    jq -r 'select(.scenario=="" and (.patterns|index("batch-launch")))
           | select(.has_timeout=="no" or .background!="true")
           | "\(.ts)  timeout=\(.has_timeout) bg=\(.background)  \(.command)"' "$L"
    # denominator — project a scalar before counting; `jq -r 'select(...)'` alone prints a
    # pretty-printed object per record and `wc -l` then counts its LINES, not its records.
    jq -r 'select(.scenario=="" and (.patterns|index("batch-launch"))) | .ts' "$L" | wc -l
Membership, not equality: a `unity test --allow-install` is `["destructive-cli","batch-launch"]`, and under
revision 2's `.pattern=="batch-launch"` it silently left this denominator.

## 7. Skill triggering — which skill actually won each moment  [R3-1]
    # every skill invocation the hook saw, bare or namespaced, in real (untagged) work
    jq -r 'select(.scenario=="" and .tool=="Skill") | .skill' "$L" | sort | uniq -c | sort -rn
    # the routing contest, collapsed to bare names
    jq -r 'select(.tool=="Skill") | .skill | sub("^[^:]+:";"")' "$L" | sort | uniq -c | sort -rn
    # TRIGGERED for one result run: join on the run's OWN session id.
    # `.skill // empty` guards a null; both sides are trimmed and lower-cased so a stray space or a
    # capitalised name cannot decide the verdict.  [R4-M3]
    jq -r --arg S "$(cat unity-ops/tests/transcripts/<tag>.session)" --arg K "unity-ops:<skill>" '
      select(.tool=="Skill" and .session_id==$S)
      | (.skill // empty) | ascii_downcase | gsub("^\\s+|\\s+$";"") as $s
      | select($s == ($K|ascii_downcase) or $s == ($K|ascii_downcase|sub("^[^:]+:";"")))' "$L" | wc -l
    # COMPETITOR_FIRED for that run — which family won, under T0.5 branch B's three competitors  [R4-E3]
    jq -r --arg S "$(cat unity-ops/tests/transcripts/<tag>.session)" '
      select(.tool=="Skill" and .session_id==$S) | (.skill // empty) | ascii_downcase' "$L" | sort | uniq -c
This is the metric that did not exist in revision 3, and its absence is why `TRIGGERED` had to be
inferred from the transcript — where a delegated skill use is invisible under `--output-format json`
and where the model's choice of the bare or namespaced name decided the verdict.

## 6. Broken-invocation rate — DENOMINATOR from the log, NUMERATOR manual
    jq -r 'select(.scenario=="" and ((([.patterns[]|startswith("live-")]|any))
             or (.patterns|index("unity-invocation")) or (.patterns|index("batch-launch")))) | .ts' "$L" | wc -l
The hook is **PreToolUse**: it runs before the command and therefore never sees an exit code. The numerator —
exit-2 / unknown-option / pager-or-prompt hangs — is counted **by hand out of the session transcripts** at the
30-day review. **Owner: whoever runs the review issue opened in Task 9.5.** This is the one metric with a manual
leg and the review issue says so explicitly rather than implying automation that does not exist.
