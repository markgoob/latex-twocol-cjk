#!/bin/sh
# log-gate.sh <file.log>
#
# The five counts that decide whether a build is clean. A zero exit code from
# LuaLaTeX proves very little for a CJK document: a glyph the font lacks is
# dropped from the PDF while the run still "succeeds". So the unit of
# verification is the log, and any non-zero count fails.
log="$1"
[ -f "$log" ] || { echo "log-gate: no such file: $log" >&2; exit 2; }
fail=0
for pattern in 'Missing character' 'Font shape .* undefined' 'Overfull' 'Underfull'; do
  n=$(grep -c "$pattern" "$log" || true)
  printf '%-30s %s\n' "$pattern" "$n"
  if [ "$n" -ne 0 ]; then
    fail=1
    grep -n "$pattern" "$log" | head -10
  fi
done
w=$(grep -cE '^(LaTeX|Package|Class) .*Warning' "$log" || true)
printf '%-30s %s\n' 'LaTeX/Package/Class Warning' "$w"
if [ "$w" -ne 0 ]; then
  fail=1
  grep -E '^(LaTeX|Package|Class) .*Warning' "$log" | sort -u
fi
exit $fail
