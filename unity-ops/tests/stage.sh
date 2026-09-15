#!/bin/bash
# unity-ops/tests/stage.sh — assemble the plugin tree a headless `claude -p` session loads.
#
#   bash unity-ops/tests/stage.sh                                 # hook only  -> the BASELINE stage
#   bash unity-ops/tests/stage.sh unity-surface-preflight [...]    # hook + those skills -> the RESULT stage
#
# The stage is rebuilt from scratch on every call, so "baseline" and "result" differ by
# exactly one directory and nothing else. `--plugin-dir` points at $STAGE and nothing else.
set -eu
SRC="${UNITY_OPS_SRC:-/Users/jeremymiranda/Dev/Unity Claude Skills/unity-ops}"
STAGE="${UNITY_OPS_STAGE:-/tmp/unity-ops-stage}"
case "$STAGE" in /tmp/*) ;; *) echo "stage.sh: refusing to rm -rf outside /tmp: $STAGE" >&2; exit 1 ;; esac
rm -rf "$STAGE"
mkdir -p "$STAGE/.claude-plugin" "$STAGE/hooks" "$STAGE/skills"
cp "$SRC/.claude-plugin/plugin.json" "$STAGE/.claude-plugin/plugin.json"
cp "$SRC/hooks/hooks.json"           "$STAGE/hooks/hooks.json"
cp "$SRC/hooks/unity-ops-guard"      "$STAGE/hooks/unity-ops-guard"
chmod +x "$STAGE/hooks/unity-ops-guard"
SEEN=""
for s in "$@"; do
  # a skill argument is a BASENAME, never a path: `../hooks` would stage the hook dir as a skill,
  # and `a/b` would nest one plugin inside another.  [R3-12]
  case "$s" in
    */*|.|..|"") echo "stage.sh: skill argument must be a bare directory name, got: $s" >&2; exit 1 ;;
  esac
  case " $SEEN " in *" $s "*) echo "stage.sh: duplicate skill argument: $s" >&2; exit 1 ;; esac
  SEEN="${SEEN:+$SEEN }$s"
  if [ ! -d "$SRC/skills/$s" ]; then echo "stage.sh: no such skill: $s" >&2; exit 1; fi
  # -L dereferences symlinks: a `references/` symlink must arrive as real files, or the child
  # session resolves it outside $STAGE and the stage stops being hermetic.  [R3-12]
  cp -RL "$SRC/skills/$s" "$STAGE/skills/$s"
  # skill-validator errors when frontmatter `name:` != the directory basename; catch it here, not
  # in marketplace CI, and never let a natural-trigger run fail for a reason that is not routing.
  NM=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^name:[[:space:]]*/{sub(/^name:[[:space:]]*/,"");gsub(/[[:space:]"'"'"']/,"");print;exit}' "$STAGE/skills/$s/SKILL.md")
  if [ "$NM" != "$s" ]; then
    echo "stage.sh: frontmatter name '$NM' != directory '$s'" >&2; exit 1
  fi
done
# skill-validator discovers ANY <plugin>/<subdir>/SKILL.md. Catch a stray one here,
# where it costs nothing, not in marketplace CI (DESIGN.md §4A).
STRAY=$(find "$STAGE" -name SKILL.md | grep -v "^$STAGE/skills/[^/]*/SKILL\.md$" || true)
if [ -n "$STRAY" ]; then echo "stage.sh: stray SKILL.md: $STRAY" >&2; exit 1; fi
# no symlink may survive into the stage
LINKS=$(find "$STAGE" -type l || true)
if [ -n "$LINKS" ]; then echo "stage.sh: symlink survived into the stage: $LINKS" >&2; exit 1; fi
echo "stage:  $STAGE"
echo "skills: $(ls "$STAGE/skills" | tr '\n' ' ')[$(ls "$STAGE/skills" | wc -l | tr -d ' ') staged]"
find "$STAGE" -type f | sed "s|^$STAGE|  .|" | sort
