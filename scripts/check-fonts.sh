#!/bin/sh
# check-fonts.sh — report which of the template's candidate font families are
# available to fontconfig, in the order \PickFont tries them.
# Linux, macOS with fontconfig, Overleaf, or inside a TeX Live container.

command -v fc-list > /dev/null 2>&1 || {
  echo "fc-list not found; install fontconfig." >&2; exit 2; }

has() { fc-list : family | tr ',' '\n' | grep -Fxq "$1"; }

check() {
  slot="$1"; shift
  for f in "$@"; do
    if has "$f"; then printf '%-18s -> %s\n' "$slot" "$f"; return 0; fi
  done
  printf '%-18s -> NONE INSTALLED\n' "$slot"
  printf '%-18s    tried: %s\n' '' "$*"
  return 1
}

missing=0
check "Latin serif (rm)" "Noto Serif" "TeX Gyre Termes" "Times New Roman" "DejaVu Serif" || missing=1
check "Latin sans  (sf)" "Noto Sans" "TeX Gyre Heros" "Arial" "DejaVu Sans" || missing=1
check "Latin mono  (tt)" "Noto Sans Mono" "DejaVu Sans Mono" "Consolas" "Courier New" || missing=1
check "CJK serif   (rm)" "Noto Serif CJK TC" "Noto Serif TC" "Source Han Serif TC" "PMingLiU" "MingLiU" "Microsoft JhengHei" || missing=1
check "CJK sans    (sf)" "Noto Sans CJK TC" "Noto Sans TC" "Source Han Sans TC" "Microsoft JhengHei" "PMingLiU" || missing=1
check "CJK mono    (tt)" "Noto Sans Mono CJK TC" "Noto Sans TC" "Microsoft JhengHei" "MingLiU" || missing=1

echo
if [ "$missing" -ne 0 ]; then
  echo "Install the missing families before building."
  echo "Debian/Ubuntu: apt install fonts-noto-cjk fonts-noto"
  echo "TeX Live:      tlmgr install noto noto-cjk"
  exit 1
fi

# Variable-font weight trap: a family served by a single VF file resolves to its
# first named instance, which for Noto TC is ExtraLight, not Regular.
vf=$(fc-list -f '%{file}\n' | grep -i -- '-VF\.ttf' | sort -u | head -8)
if [ -n "$vf" ]; then
  echo "Variable fonts present:"
  echo "$vf" | sed 's/^/  /'
  echo "The template pins RawFeature={axis={wght=400}} for these — keep it,"
  echo "or Chinese text renders in ExtraLight with no warning."
fi

echo "All font slots resolved."
