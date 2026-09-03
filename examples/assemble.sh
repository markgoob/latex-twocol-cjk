#!/bin/sh
# assemble.sh <example-name>
#
# Build examples/<name>/main.tex from the shared preamble plus that example's
# body.tex, exactly the way SKILL.md tells a user to start a document: take
# references/template.tex up to (not including) the "% --- TITLE & AUTHORS"
# marker, then append the document-specific part.
#
# The marker is matched anchored at line start and the LAST match is used, so
# a comment that merely mentions the marker can never cut the preamble short.
set -e
name="$1"
[ -n "$name" ] || { echo "usage: sh examples/assemble.sh <example-name>" >&2; exit 2; }

root=$(cd "$(dirname "$0")/.." && pwd)
tpl="$root/references/template.tex"
body="$root/examples/$name/body.tex"
out="$root/examples/$name/main.tex"
[ -f "$body" ] || { echo "no such example body: $body" >&2; exit 2; }

n=$(grep -n '^% --- TITLE & AUTHORS' "$tpl" | tail -1 | cut -d: -f1)
[ -n "$n" ] || { echo "marker not found in $tpl" >&2; exit 1; }

{
  head -n $((n - 1)) "$tpl"
  cat "$body"
} > "$out"
echo "assembled $out ($(wc -l < "$out") lines; preamble = template lines 1-$((n - 1)))"
