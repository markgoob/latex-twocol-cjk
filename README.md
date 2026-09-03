**English** | [繁體中文](README.zh-TW.md)

# latex-twocol-cjk

A Claude skill for two-column, A4, IEEE-style LaTeX documents that mix CJK and
Latin text — the kind of thing you write for an internal whitepaper, a technical
report, or a course paper in Traditional Chinese.

It exists because the obvious setup does not work. The common advice for
CJK-in-babel pairs `bidi=basic` and `onchar=ids fonts` with XeLaTeX, and that
combination cannot produce a PDF: `bidi=basic` is a LuaTeX-only method and babel
raises a hard error on it, while `onchar` is also LuaTeX-only but fails silently,
so the per-character font switching everything depends on never runs.

## What it prevents

Three failures, all reproduced against TeX Live 2026 before being written down.

**The engine mismatch.** Build with LuaLaTeX, and drop `bidi=` entirely — an
LTR-only Chinese/English document has no use for it.

**Wrong-locale captions.** babel has `chinese-traditional` (zh-Hant) and
`chinese-simplified` (zh-Hans). Reaching for the `japanese` locale instead gives
you 図 / 表 / 参考文献 and Japanese date format: wrong language, and wrong glyph
forms for a Chinese document. This skill keeps `english` as the main language and
adds the CJK locale as secondary, so captions stay English as IEEE wants while
CJK text still gets the right font, line-breaking, and `zh-Hant` tagging.

**Fonts, twice over.** The same typeface ships as `Noto Serif CJK TC` from the
noto-cjk repo, Linux packages, and Overleaf, but as `Noto Serif TC` from Google
Fonts — which is what a Windows user actually installs. Hard-coding either name
makes fontspec abort. Worse, the Google build is a single variable file whose
first named instance is styled `ExtraLight,Regular` at weight 40, so a plain
family-name lookup silently sets your Chinese body text in ExtraLight, visibly
thinner than the Latin beside it, with no warning at all.

The template solves both: `\PickFont` walks a candidate list down to Windows
in-box `PMingLiU` / `Microsoft JhengHei`, and the weight axis is pinned:

```latex
UprightFeatures = {RawFeature={axis={wght=400}}},
BoldFont = {*}, BoldFeatures = {RawFeature={axis={wght=700}}},
```

Pinning also buys a real bold instead of a faked one, and static families ignore
the feature without complaint.

Regional subsets also have holes: Google's `Noto Serif TC` has no Japanese 図,
and a glyph the font lacks simply vanishes from the PDF with one log line. When
a wider font is installed (full-repertoire Noto CJK, Microsoft JhengHei), the
template attaches it as a luaotfload glyph fallback so the character prints
from there instead.

A diagnostic note, since it cost time to learn: `pdffonts` cannot tell you
whether the axis took. Subset names come from the base font's PostScript name,
so a correctly pinned run still reports `NotoSerifTC-ExtraLight`. Measure the
rendered ink instead.

## Scope

This builds on `article`, not `IEEEtran`. The output looks like an IEEE paper and
is right for internal reports and course papers. It is **not** camera-ready for
an actual IEEE submission — margins, abstract width, and caption metrics differ,
and submission checkers will reject it. For a real submission, use `IEEEtran` and
port only the font block from here.

## Install

Copy the repository contents into a skill directory:

```bash
git clone https://github.com/markgoob/latex-twocol-cjk
mkdir -p ~/.claude/skills/latex-twocol-cjk
cp -r latex-twocol-cjk/{SKILL.md,references,scripts} ~/.claude/skills/latex-twocol-cjk/
```

On Windows the directory is `C:\Users\<you>\.claude\skills\latex-twocol-cjk\`.
Skills register in a running session immediately; no restart.

You can also use the template on its own, without Claude — `references/template.tex`
is a complete, self-contained document.

## Build

```bash
latexmk -lualatex -interaction=nonstopmode main.tex
```

Check the fonts before the first build, since a missing family is a fatal error
rather than a warning:

```bash
scripts/check-fonts.sh          # Linux, macOS, Overleaf, containers
scripts\check-fonts.ps1         # Windows
```

No TeX installed? `scripts/build.ps1 main.tex` compiles in a TeX Live container
with the machine's own fonts mounted, so the build sees the real font environment
rather than a generic Linux one.

On Overleaf the `% !TeX program` line is ignored — set Menu → Compiler → LuaLaTeX
by hand. Overleaf already carries the Noto CJK fonts.

## Reading the log

A clean exit code does not mean a clean document. `Missing character` means a
glyph was dropped from the PDF; the build still succeeds.

| Signal | Meaning |
|---|---|
| `Missing character` | glyph silently dropped — the font is wrong |
| `Font shape … undefined` | a face was substituted; bold or italic CJK is faked |
| `Overfull \hbox` in the bibliography | the `\raggedright` wrapper is missing |
| `Too many unprocessed floats` | add `\FloatBarrier` |
| `There were undefined references` | run again |

`references/troubleshooting.md` maps 23 errors to causes and fixes, with the log
excerpts they actually produce.

## Prose, not just typesetting

Setting a Chinese page correctly and writing acceptable Chinese are different
jobs, and the second one is what a reviewer reacts to first. `SKILL.md` §9
covers the part that overlaps with LaTeX: Taiwan rather than mainland
terminology, full-width punctuation and the two ways LaTeX quietly substitutes
the Latin forms (backtick quoting, `\ldots`), the half-width space at every
CJK/Latin boundary, and the padding that abstracts attract.

If [be-human-v1](https://github.com/markgoob/be-human-v1) is installed alongside
this skill, it takes over prose by default — no invocation — and §9 defers to it
on wording and punctuation. This skill keeps authority over anything that
changes how the page sets. Neither skill requires the other to work.

## Contents

| Path | What it is |
|---|---|
| `SKILL.md` | the rules, in document-construction order |
| `references/template.tex` | complete verified document; copy the preamble |
| `references/troubleshooting.md` | error → cause → fix |
| `scripts/check-fonts.ps1`, `.sh` | which candidate families are installed |
| `scripts/build.ps1` | containerised build for machines with no TeX |
| `scripts/package-skill.ps1` | build a `.skill` archive installers accept |

## Verification

`references/template.tex` compiles under TeX Live 2026 (LuaHBTeX 1.24.0) with
Google-Fonts Noto TC installed on Windows 11, producing a two-page PDF with zero
`Missing character`, zero undefined font shapes, zero overfull or underfull
boxes, and zero LaTeX, Package, or Class warnings. Treat any warning as a defect
you introduced.

Two rules come from a 12-page zh-Hant paper rather than from the template: a
source line broken between two Han characters prints a visible space (TeX turns
the newline into a space before babel sees it), and `intraspace` on the locale is
the lever for loose Chinese lines, not `\sloppy`. Both are in `SKILL.md` §8 and
`troubleshooting.md` E17–E19.

## License

MIT. See `LICENSE`.
