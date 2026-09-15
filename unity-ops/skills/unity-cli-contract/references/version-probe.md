# Version probe

The binary is the only authority, and only for what you actually probed this session. Everything below
is how you get that authority cheaply, in one or two commands, before you make a claim someone acts on.

## The five rules

1. **`unity --version` once per session; record `beta.N`.** Then *say* the number in any answer whose truth
   depends on it. "This CLI version" is not a version. Three baseline reps each told a user that a flag did
   not exist without ever naming the binary the claim was true of, on a machine running `1.0.0-beta.8`.
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
```

`exit=1` from an anchored grep over the binary's own help is evidence. A reference page that happens not to
mention the flag is not — it is silence, and silence is not a denial.

## Absence of a flag is not absence of the capability

The probe above licenses exactly one sentence: *`unity test` has no `--affected` on this binary.* It does
not license *"there is no changed-file test selection here"*. Those are different claims about different
scopes, and on beta.8 the second one is false:

```
$ unity vcs --help                  # read the Commands: list, look for the capability, not the flag
$ unity vcs affected --help
Usage: unity vcs affected [options] [path]
Report which assets, assemblies, and tests a change affects
  --since <ref>      Revision to compare against. Its merge base with HEAD is used.
```

So the full answer to "run only what changed" on beta.8 is `unity vcs affected --since <ref>` plus a
filtered `unity test`, not "that capability does not exist". Before you deny a capability, probe the verb
that would own it, not only the verb the user happened to name.

## The dependency check — anchor the match

`installed` is a substring of `not installed`, so an unanchored grep reports success on the failure case.
Match the negative first and let it decide:

```
# read the row itself, do not just count a match
$ unity skill install --list | grep -i 'claude-code'

# the anchored decision: 1 means the dependency is NOT satisfied -> hard stop
$ unity skill install --list | grep -ic 'claude-code.*not installed'
```

On `1`, stop. Tell the user to run `unity skill install claude-code` and do nothing else — no degraded
workflow, no reconstruction of Unity's command reference from memory, no copy of it into this plugin.
