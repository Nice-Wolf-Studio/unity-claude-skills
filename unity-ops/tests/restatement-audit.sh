#!/bin/bash
# unity-ops conformance check 7 — restatement budget, MEASURED by WORD COVERAGE.  [R3-2]
# Usage: bash unity-ops/tests/restatement-audit.sh <SKILL.md> [reference-tree ...]
# Default reference tree: the INSTALLED unity-cli skill (the copy agents actually load).
#
# Metric: for each countable body line, k = min(6, words) with a floor of 4; a k-shingle that
# appears anywhere in the reference tree marks its k words as covered; the line is RESTATED when
# >= 60% of its words are covered. Structural lines (fence markers, `|---|`, headings) and lines
# with fewer than 4 normalized words are excluded from BOTH numerator and denominator — a short
# line carries no evidence either way, and counting it as "original" is how revision 3's line-hit
# metric scored an all-verbatim table 0.00.
set -u
SKILL="${1:?path to SKILL.md}"; shift
REFS=("$@"); [ ${#REFS[@]} -eq 0 ] && REFS=("$HOME/.claude/skills/unity-cli")
SKILL="$SKILL" python3 - "${REFS[@]}" <<'PY'
import os, re, sys, pathlib

KMIN, KMAX = 4, 6          # shingle widths built for the reference tree
MINWORDS   = 4             # a line with fewer normalized words is not evidence
COVER      = 0.60          # >= this share of a line's words covered => the line is restated
BUDGET     = 0.25          # conformance check 7 gate

WORD  = re.compile(r"[^a-z0-9]+")
FENCE = re.compile(r"^\s*(```|~~~)")
RULE  = re.compile(r"^\s*\|?[\s:|+-]+\|?\s*$")     # |---|---|, ---, ===
HEAD  = re.compile(r"^\s*#{1,6}\s")

def norm(s): return [w for w in WORD.sub(" ", s.casefold()).split() if w]
def shingles(words, k): return {" ".join(words[i:i+k]) for i in range(len(words)-k+1)}

ref = {k: set() for k in range(KMIN, KMAX + 1)}
files = 0
for root in sys.argv[1:]:
    p = pathlib.Path(root)
    for f in (sorted(p.rglob("*.md")) if p.is_dir() else [p]):
        w = norm(f.read_text(errors="replace"))
        for k in ref: ref[k] |= shingles(w, k)
        files += 1

text = pathlib.Path(os.environ["SKILL"]).read_text(errors="replace").splitlines()
# drop YAML frontmatter: the description is a trigger contract, not body prose
if text and text[0].strip() == "---":
    end = next((i for i, l in enumerate(text[1:], 1) if l.strip() == "---"), 0)
    text = text[end + 1:]

counted, hits, excluded = 0, [], 0
for line in text:
    if FENCE.match(line):                       excluded += 1; continue   # the ``` marker itself
    if not line.strip():                        continue
    if HEAD.match(line) or RULE.match(line):    excluded += 1; continue
    w = norm(line)
    if len(w) < MINWORDS:                       excluded += 1; continue
    k = max(KMIN, min(KMAX, len(w)))
    cov = [False] * len(w)
    for i in range(len(w) - k + 1):
        if " ".join(w[i:i + k]) in ref[k]:
            for j in range(i, i + k): cov[j] = True
    counted += 1
    c = sum(cov) / len(w)
    if c >= COVER: hits.append((c, line))

share = len(hits) / counted if counted else 0.0
print(f"reference files: {files}   shingle widths: {KMIN}-{KMAX}   "
      f"reference shingles: {sum(len(v) for v in ref.values())}")
print(f"countable body lines: {counted}   restated lines: {len(hits)}   "
      f"share: {share:.3f} ({len(hits)}/{counted})   excluded (structural or <{MINWORDS} words): {excluded}")
for c, l in hits: print(f"   RESTATED [cov {c:.2f}]:", l.strip()[:110])
print(f"RESTATEMENT: {'PASS' if share <= BUDGET else 'FAIL'} "
      f"(budget {BUDGET:.3f}, line-coverage threshold {COVER:.2f})")
sys.exit(0 if share <= BUDGET else 1)
PY
