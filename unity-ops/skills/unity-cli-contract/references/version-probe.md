# Version probe

The binary is the only authority, and only for what you actually probed this session. Everything below
is how you get that authority cheaply, in one or two commands, before you make a claim someone acts on.

## The five rules

1. **`unity --version` once per session; record `beta.N`.** Then open every statement about what this CLI
   has or lacks with `on 1.0.0-beta.N, …`. Not "when it matters" — always, because presence and absence are
   both properties of one build. "This CLI version" is not a version. In the T3.2 baseline all three reps
   told a user a flag did not exist and not one named the binary the claim was true of.
2. **Before relying on a flag you have not personally seen this session, probe the parent command's
   `--help`** and read its `Commands:` list and its options block. Your loaded reference is a second-hand
   account; `--help` is the binary answering for itself.
3. **Root help printed is never evidence of absence.** Nested subcommands have been **observed
   intermittently** printing the root help instead of their own: the same invocation printed root help once
   and correct subcommand help on three immediate re-runs — with and without env vars, piped and not,
   exit 0 every time. So re-run the identical invocation, then probe the parent's `Commands:` list. The
   behaviour is not reliable in either direction, which is exactly why a single printout decides nothing.
4. **Both written copies are unreliable in both directions.** The copy installed under
   `~/.claude/skills/unity-cli` trails the public one; the public one runs ahead of the binary; and the
   binary carries verbs neither copy names. A gap in a document is a gap in that document.
5. **Pin nothing to a changelog.** Neither copy's changelog is authority over the binary you are about to
   run. Compare the version you recorded in rule 1 against a probe, never against a release note.

## Establishing absence — the worked example

This is the whole technique. Two lines, no guessing, and a result you can quote:

```
$ unity test --help | grep -i affected
$ echo "exit=$?"
exit=1        # no match -> the flag is not on this binary. THIS is how you establish absence.
              # and the sentence you hand back, version first, because the probe was of one build:
              #   "on 1.0.0-beta.8, unity test has no --affected."
```

`exit=1` from an anchored grep over the binary's own help is evidence. A reference page that happens not to
mention the flag is not — it is silence, and silence is not a denial. The same sentence without the version
is not an answer either: it tells the user something true of a build they cannot identify.

## Absence of a flag is not absence of the capability

The probe above licenses exactly one sentence: *`unity test` has no `--affected` on this binary.* It does
not license *"there is no changed-file test selection here"*. Those are different claims about different
scopes, and on beta.8 the second one is false:

```
$ unity vcs --help              # read the Commands: list — hunt the capability, not the flag
$ unity vcs affected --help     # beta.8 answers here; its options block carries the compare-against flag
```

Those two commands are the work. This page deliberately does not paste what they print: an answer copied
from a page you read is the failure this skill exists to prevent, and the second probe is also where you
get the option spelling to quote. Before you deny a capability, probe the verb that would own it, not only
the verb the user happened to name — then report it version first, with the verb you actually ran.

## The dependency check — anchor the match

`installed` is a substring of `not installed`, so an unanchored grep reports success on the failure case.
Match the negative first and let it decide:

```
# read the row itself, do not just count a match
$ unity skill install --list | grep -i 'claude-code'

# the anchored decision: 1 means the dependency is NOT satisfied -> hard stop
$ unity skill install --list | grep -ic 'claude-code.*not installed'
```

**A `0` from that count is only half an answer.** It is what "installed" looks like — and equally what a
failed command, a vanished row and a changed output shape look like. So settle the row's existence before
you read the count: the first command must exit 0 **and** print a `claude-code` row. `unity skill install
--list --format json` is the cleaner form of the same check on beta.8, returning a `success` envelope whose
per-client entries you can read instead of inferring from a count; either way, no row seen means no
dependency established, which is a stop and not a pass.

On `1`, stop. Tell the user to run `unity skill install claude-code` and do nothing else — no degraded
workflow, no reconstruction of Unity's command reference from memory, no copy of it into this plugin.
