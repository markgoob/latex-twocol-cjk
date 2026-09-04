**English** | [繁體中文](README.zh-TW.md)

# latex-twocol-cjk

A Claude skill for two-column A4 papers that mix CJK and Latin text — internal
whitepapers, technical reports, course papers. It gives Claude a LuaLaTeX
preamble that compiles on the first run, and the rules that keep it compiling as
the document grows.

It exists because the setup most guides recommend cannot produce a PDF at all.
Pairing `bidi=basic` with `onchar=ids fonts` under XeLaTeX fails twice over:
`bidi=basic` is a LuaTeX-only method and babel stops on it with a hard error,
while `onchar` is also LuaTeX-only but fails quietly, so the per-character font
switching that the rest of the recipe depends on never happens.

## What it produces

<p align="center">
  <a href="examples/skill-intro/skill-intro.pdf"><img src="examples/skill-intro/preview/page-1.png" width="32%" alt="skill-intro example, page 1"></a>
  <a href="examples/skill-intro/skill-intro.pdf"><img src="examples/skill-intro/preview/page-2.png" width="32%" alt="skill-intro example, page 2"></a>
  <a href="examples/skill-intro/skill-intro.pdf"><img src="examples/skill-intro/preview/page-3.png" width="32%" alt="skill-intro example, page 3"></a>
</p>

[`examples/skill-intro/skill-intro.pdf`](examples/skill-intro/skill-intro.pdf) —
a three-page introduction to the skill, written with the skill: Chinese body
text, English and Chinese abstracts, TikZ figures including a two-panel
`figure*`, three tables, and all five log counts at zero. Click a page to open
the PDF; the source is in [`examples/skill-intro/`](examples/skill-intro/).

## Install

Copy the skill files into a skill directory:

```bash
git clone https://github.com/markgoob/latex-twocol-cjk
mkdir -p ~/.claude/skills/latex-twocol-cjk
cp -r latex-twocol-cjk/{SKILL.md,references,scripts} ~/.claude/skills/latex-twocol-cjk/
```

On Windows that directory is `C:\Users\<you>\.claude\skills\latex-twocol-cjk\`.
Skills register in a running session immediately; no restart.

The [Releases](https://github.com/markgoob/latex-twocol-cjk/releases) page also
carries a `.skill` archive. Installers take it as is; to unpack it by hand,
rename it to `.zip` — the archive root is the skill folder itself.

You can also use the template without Claude. `references/template.tex` is a
complete, self-contained document.

## Build

Copy `references/template.tex` to `main.tex` in your project, or keep everything
above its `% --- TITLE & AUTHORS` marker as the preamble and write your own body
under it. Then:

```bash
latexmk -lualatex -interaction=nonstopmode main.tex
```

Two things stop a first build outright rather than merely warning. One is a
missing font family:

```bash
sh scripts/check-fonts.sh   # Linux, macOS (needs fontconfig), Overleaf, containers
scripts\check-fonts.ps1     # Windows
```

The other is a minimal TeX Live, which lacks several packages the template
loads — `balance.sty` comes from `preprint`, and `subcaption` from `caption`:

```bash
tlmgr install preprint titlesec placeins xurl multirow
```

No TeX installed? `scripts/build.ps1 main.tex` compiles in a TeX Live container
with the machine's own fonts mounted, so the build sees the real font
environment rather than a generic Linux one.

On Overleaf the `% !TeX program` line is ignored — set Menu → Compiler →
LuaLaTeX by hand. The Noto CJK fonts are already there.

## Three traps it removes

All three are reproducible under TeX Live 2026.

**Engine.** Build with LuaLaTeX, and drop `bidi=` entirely — an LTR-only
Chinese and English document has no use for it.

**Locale.** babel ships `chinese-traditional` (zh-Hant) and
`chinese-simplified` (zh-Hans). Reaching for the `japanese` locale instead gives
you 図 / 表 / 参考文献 and a Japanese date format: wrong language, and wrong
glyph forms for a Chinese document. The template keeps `english` as the main
language and adds the CJK locale as secondary, so captions stay English as IEEE
expects while Chinese text still gets the right font, line breaking, and
`zh-Hant` tagging. Traditional Chinese is the verified default; when the
document really is in another language, `chinese-simplified`, `japanese` and
`korean` are a one-line swap in the preamble, Korean additionally needing a KR
font because it breaks lines on spaces rather than between characters.

**Fonts, twice over.** The same typeface ships as `Noto Serif CJK TC` from the
noto-cjk repo, Linux packages, and Overleaf, but as `Noto Serif TC` from Google
Fonts — which is what a Windows author actually installs. Hard-code either name
and fontspec aborts. The second trap is quieter. The Google build is a single
variable file whose first named instance is styled `ExtraLight,Regular` at
weight 40, so a plain family-name lookup sets your Chinese body text in
ExtraLight, visibly thinner than the Latin beside it, with no warning at all.

`\PickFont` settles the naming by walking a candidate list down to the Windows
in-box `PMingLiU` and `Microsoft JhengHei`. The weight comes from pinning the
axis:

```latex
UprightFeatures = {RawFeature={axis={wght=400}}},
BoldFont = {*}, BoldFeatures = {RawFeature={axis={wght=700}}},
```

which also buys a real bold instead of a faked one. Static families ignore the
feature without complaint, so one block covers both kinds of font.

Two further font facts are worth knowing. Regional subsets have holes — Google's
`Noto Serif TC` has no Japanese 図, and a glyph the font lacks simply vanishes
from the PDF with one line in the log; where a wider font is installed
(full-repertoire Noto CJK, Microsoft JhengHei), the template attaches it as a
luaotfload glyph fallback so the character prints from there. And `pdffonts`
cannot tell you whether the axis took, because subset names come from the base
font's PostScript name: a correctly pinned run still reports
`NotoSerifTC-ExtraLight`. Measure the rendered ink instead.

## Scope: IEEE-style, not IEEE-submittable

This builds on `article`, not `IEEEtran`. The output looks like an IEEE paper
and is right for internal reports and course papers. It is **not** camera-ready
for an actual IEEE submission — margins, abstract width, and caption metrics
differ, and submission checkers will reject it. For a real submission, use
`IEEEtran` and port only the font block from here.

Two departures from real IEEE are deliberate, and worth being able to explain:
the abstract spans both columns rather than `IEEEtran`'s single-column width,
and body text is Noto Serif rather than Times, so that it sits with the Chinese
face.

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

`references/troubleshooting.md` maps 24 errors to causes and fixes, with the log
excerpts they actually produce.

## Writing the Chinese, not just setting it

Setting a Chinese page correctly and writing acceptable Chinese are different
jobs, and the second one is what a reviewer reacts to first. `SKILL.md` §9
covers the part that overlaps with LaTeX: Taiwan rather than mainland
terminology, full-width punctuation and the two ways LaTeX quietly substitutes
the Latin forms (backtick quoting, `\ldots`), the half-width space at every
CJK/Latin boundary, and the padding that abstracts attract.

Two source-formatting rules bite before any of that (`SKILL.md` §8,
`troubleshooting.md` E17–E19): a source line broken between two Han characters
prints a visible space, because TeX turns the newline into a space before babel
sees the text, and the lever for loose Chinese lines is `intraspace` on the
locale, not `\sloppy`.

If [be-human-v1](https://github.com/markgoob/be-human-v1) is installed alongside
this skill, it takes over prose by default — no invocation — and §9 defers to it
on wording and punctuation. This skill keeps authority over anything that
changes how the page sets. Neither skill requires the other to work.

## What is in the repo

| Path | What it is |
|---|---|
| `SKILL.md` | the rules, in document-construction order |
| `references/template.tex` | complete verified document; copy the preamble |
| `references/troubleshooting.md` | error → cause → fix |
| `scripts/check-fonts.ps1`, `.sh` | which candidate families are installed |
| `scripts/build.ps1` | containerised build for machines with no TeX |
| `scripts/package-skill.ps1` | build a `.skill` archive installers accept |
| `scripts/log-gate.sh` | the five log counts; any non-zero fails |
| `examples/` | complete documents written with the skill, rebuilt by CI against the current template |

## Verified

`references/template.tex` compiles under TeX Live 2026 (LuaHBTeX 1.24.0) to a
two-page PDF with zero `Missing character`, zero undefined font shapes, zero
overfull or underfull boxes, and zero LaTeX, Package, or Class warnings. Both
font namings are covered: Google Fonts Noto TC on Windows 11, and Debian's
`fonts-noto-cjk`.

CI reruns those checks on every change to the template and the examples, and
**any warning fails the build**. That strictness is necessary, because LuaLaTeX
exits 0 while dropping the glyphs it has no font for, so a green exit code
proves nothing by itself. Treat a warning as a defect you introduced.

## License

MIT. See `LICENSE`.
