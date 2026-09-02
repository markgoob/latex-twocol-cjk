---
name: latex-twocol-cjk
description: >
  Use this skill whenever the user wants a LaTeX document that is two-column,
  A4, contains CJK characters (Traditional Chinese, Simplified Chinese,
  Japanese, or Korean), or resembles an IEEE-style paper, whitepaper, or
  technical report with TikZ diagrams, benchmark tables, code listings, or
  Docker configs. Also trigger on "雙欄 LaTeX", "兩欄排版", "技術文件 LaTeX",
  "技術白皮書", "論文格式", "期刊論文", "研討會論文", "投稿", "IEEE 論文",
  "IEEE paper", "conference paper", "seminar paper", or any LaTeX document
  mixing Chinese/Japanese/Korean with English. The skill encodes verified
  LuaLaTeX + babel + fontspec rules that prevent CJK font failures, wrong-locale
  captions, variable-font weight errors, two-column float disasters, and
  bibliography stretching. Even if the user only says "make me a LaTeX report",
  check whether CJK or two-column is involved and use this skill if so.
---

# LaTeX Two-Column CJK Technical Document (IEEE Style)

## Quick start

1. Copy everything in `references/template.tex` above the `END PREAMBLE` marker.
2. Replace the body. Keep the `\twocolumn[\begin{@twocolumnfalse} … ]` title block.
3. Build with `latexmk -lualatex -interaction=nonstopmode main.tex`.
4. Check the log: `Missing character` or `Font shape … undefined` means the font
   setup is wrong, not that the document is fine. See `references/troubleshooting.md`.

The template compiles clean — zero warnings, zero missing characters, zero
overfull boxes — on TeX Live 2026 with Windows-installed Noto TC fonts. Keep it
that way: every warning it emits is a defect you introduced.

Writing the Chinese prose is a separate job from setting it, and §9 governs it.
If `be-human-v1` is installed, that skill is in force by default for every word
of prose here — read §9 before drafting the abstract, not after.

## Scope warning: IEEE-*style*, not IEEE-submittable

This builds on `article`, not `IEEEtran`. The output looks like an IEEE paper
and is right for internal whitepapers, technical reports, and course papers.
It is **not** camera-ready for an actual IEEE submission: margins, abstract
width, and caption metrics differ, and checkers will reject it. For a real
submission use `IEEEtran` and port only the font block from this template.

Two deliberate departures from real IEEE, so you can defend them: the abstract
here spans both columns (IEEEtran keeps it at column width), and the body face
is Noto Serif rather than Times, chosen to match the CJK face.

---

## 1. Engine and language — get this right first

**Use LuaLaTeX. Not XeLaTeX.** babel's `onchar=ids fonts`, the option that
switches fonts per character between CJK and Latin, is LuaTeX-only. Under
XeLaTeX it does nothing, and `bidi=basic` is a hard error that stops the build.
Never pass `bidi=` at all in an LTR-only CJK/Latin document; it buys nothing.

**Use the Chinese locale for Chinese.** babel ships `chinese-traditional`
(zh-Hant) and `chinese-simplified` (zh-Hans). Do not reach for `japanese` —
it sets captions to 図/表/参考文献 and dates to Japanese format, which are both
the wrong language and the wrong glyph forms for a Chinese document.

**Keep English as the main language**, then add the CJK locale as secondary:

```latex
\usepackage[english, provide=*]{babel}
\babelprovide[import, onchar=ids fonts]{chinese-traditional}
```

This is what keeps `\figurename`, `\tablename`, `\refname`, and `\today` in
English, as IEEE wants, while CJK characters still get the right font, the right
line-breaking, and correct `zh-Hant` tagging in the PDF.

Swap the locale for other scripts: `chinese-simplified`, `japanese`, `korean`.
Korean also needs a KR font and breaks lines at spaces, not between characters.

## 2. Fonts — the two traps that waste the most time

Copy the font block from `references/template.tex` verbatim. It handles both:

**Trap 1: family names differ by distribution.** The same typeface is
`Noto Serif CJK TC` from the noto-cjk repo, Linux packages, and Overleaf, but
`Noto Serif TC` from Google Fonts, which is what a Windows user installs.
Hard-coding either name makes fontspec abort with a fatal *font cannot be
found*. The template's `\PickFont` walks a candidate list and takes the first
family actually present, ending at Windows in-box `PMingLiU` / `Microsoft
JhengHei`.

**Trap 2: variable fonts land on the wrong weight.** Google's
`NotoSerifTC-VF.ttf` exposes a first named instance styled `ExtraLight,Regular`
at weight 40. Ask for the family by name and you silently get ExtraLight —
Chinese noticeably thinner than the Latin beside it, with no warning at all.
Pin the axis instead, which also yields a real bold rather than a smeared fake
one and is ignored harmlessly by static fonts:

```latex
UprightFeatures = {RawFeature={axis={wght=400}}},
BoldFont = {*}, BoldFeatures = {RawFeature={axis={wght=700}}},
```

**Declare `rm`, `sf`, and `tt` for both scripts.** Setting only `rm` is the
common mistake: CJK inside `\texttt`, `Verbatim` blocks, and `\sffamily` TikZ
node labels then falls to a Latin font with no CJK glyphs, and those characters
are dropped from the PDF with only a log warning. Chinese comments in a
docker-compose listing is exactly the case that breaks.

CJK families have no italic and no small caps. Map `ItalicFont`,
`BoldItalicFont`, and `SmallCapsFont` back onto the same file with `FakeSlant`,
as the template does, or `\scshape` on every `\section` emits warnings. Caveat
that no setting fixes: in a heading mixing scripts, the Latin half small-caps
and the Chinese half cannot. For mostly-Chinese headings use `\bfseries`.

Run `scripts/check-fonts.ps1` (or `.sh`) before the first build.

## 3. Title block, abstract, keywords

The full-width title block uses `\twocolumn[\begin{@twocolumnfalse} … ]`.

- The `abstract` and `IEEEkeywords` environments **emit the `Abstract—` and
  `Index Terms—` labels themselves**. Never type the label again in the body.
- 150–250 words. No citations, equations, or figure references.
- `\thanks` and footnotes are **lost** inside this block — the material is
  typeset outside the main galley. Put funding and corresponding-author notes
  in the affiliation lines, or emit `\footnotetext` after the block.
- For a Taiwanese venue wanting 中英雙摘要, the template carries `cnabstract`
  and `cnkeywords` environments. Chinese block second, after the English one.

## 4. Headings and cross-references

`titlesec` gives the four IEEE levels: Roman centred small caps, letter italic,
`1)` run-in, `a)` run-in.

**Redefine `\thesection` too, not just the titlesec label.** The label argument
only changes what the heading displays; `\ref` reads `\thesection`. Miss this
and `Section~\ref{sec:x}` prints "Section 2" against a heading reading "II.".
The template sets `\thesection` to `\Roman`, `\thesubsection` to `II-A` form.

`Acknowledgment` (singular) and `References` are unnumbered `\section*`.
For appendices, `\appendix` alone never prints the word "Appendix" — it only
switches `\thesection` to `\Alph`, and the hardcoded Roman label would collide
with the body sections. Use the retitling block commented in the template.

Cross-reference style: `Fig.~\ref{}` (abbreviated, even at the start of a
sentence), `Table~\ref{}` (never abbreviated), `\eqref{}`, `Section~\ref{}`.
Inside a citation: `[5, Fig.~1]`, `[5, Table~III]`.

## 5. Floats — the top source of two-column layout disasters

- `\raggedbottom` immediately after `\begin{document}`. Without it LaTeX
  stretches inter-paragraph glue to equalise column bottoms, gouging whitespace
  around every float.
- Never `[H]`. Use `[!t]`, IEEE's placement, and let LaTeX reflow. Do not load
  the `float` package at all — its only draw is the `[H]` you must not use.
- `\FloatBarrier` (from `placeins`) before a `\section` that follows a
  float-heavy one, to stop floats drifting past section boundaries.
- Full-width floats go in `figure*` / `table*` with `\textwidth`.
- The float-fraction parameters in the template's preamble are tuned; keep them.
- "Too many unprocessed floats" means the queue overflowed — add a
  `\FloatBarrier` or `\clearpage`.

## 6. Figures and tables

Caption **below** figures, **above** tables. The `caption` package setup in the
template produces IEEE's `Fig. 1.` and centred small-caps `TABLE I`; article's
default is `Figure 1:` with a colon, so the setup is load-bearing, not decoration.

- Tables number in Roman: `\renewcommand{\thetable}{\Roman{table}}`.
- `tabularx` at `\columnwidth`; use the template's `Y` column (raggedright X)
  for prose cells. A justified 2 cm column produces huge word gaps.
- Numeric benchmark columns: `siunitx` `S` columns so decimal points align.
- Subfigures via `subcaption`, labelled `(a)`/`(b)`, referenced as `Fig. 2a`.
- Table footnotes: `\raggedright` plus `\par\vspace{2pt}` between entries;
  superscript markers as `\rlap{$^{\star}$}`.

## 7. Code, math, TikZ

- `fancyvrb` with `\fvset{fontsize=\scriptsize}`; default monospace is too wide
  for one column. Verbatim blocks over ~30 lines will break the column — split
  them. `listings` handles multibyte text poorly; `minted` needs Pygments and
  `-shell-escape`.
- CJK in math must be wrapped: `$P_{\text{尖峰}}$`. babel's onchar switching
  acts on text, not on math atoms, so bare CJK in math loses its font.
- TikZ: wrap in `\resizebox{\columnwidth}{!}{…}`, place with `[!t]`, use
  `figure*` and `\textwidth` for full width. For many diagrams, precompile each
  with the `standalone` class and `\includegraphics` the results; that beats
  fighting `\tikzexternalize` under LuaLaTeX.

## 8. Two source-formatting rules for Chinese body text

Both cost real hours on a first long document, and neither is visible until the
PDF is in front of you.

**Never break a source line between two Han characters.** TeX turns end-of-line
into a space during tokenisation, before babel ever sees the text, so
`onchar=ids fonts` cannot remove it. Every wrapped line of Chinese then shows a
visible gap mid-sentence. Either keep each Chinese paragraph on one long source
line, or join only the lines whose last character and next line's first
character are both Han — leave Chinese/Latin boundaries and table rows alone,
since those need their space.

**Type a real half-width space at every Chinese/Latin boundary** — 用 Dorico
記譜, 共 631 條. babel does not insert one automatically the way xeCJK does.
This is the one authoring habit the babel route costs you, and it is the exact
case the rule above must not "fix".

If lines still set loosely, the lever is `intraspace` on the locale, not
`\sloppy`. See the preamble comment and `troubleshooting.md` E19.

## 9. Prose style for the Chinese text

Everything above governs how the page sets. The words are a separate problem,
and in a zh-Hant paper they are the half a reviewer reacts to first.

**If the `be-human-v1` skill is installed, it is in force by default** for every
word of prose written into these documents — title, abstract, body, captions,
acknowledgment — without being invoked. It carries the full Taiwan-usage and
punctuation layer and the de-AI-tone framework. Where the two overlap,
`be-human-v1` decides wording and punctuation; this skill decides anything that
changes how the page sets. Get it at
<https://github.com/markgoob/be-human-v1>.

Standing alone, apply at least the four below. They are the ones that actually
show up in Chinese technical writing.

**Taiwan terms, not mainland ones.** 資料 not 數據 (keep 數據 only for numeric
statistics), 軟體/硬體 not 軟件/硬件, 程式 not 程序, 最佳化 not 優化, 訊號 not
信號, 介面 not 界面, 預設 not 默認, 相容 not 兼容, 模擬 not 仿真, 向量/純量 not
矢量/標量, 機率 not 概率. Three are sense-dependent rather than banned outright:
品質 for quality but 質量 for physical mass, 水準 for standard but 水平 for
horizontal, 透過 for by-means-of but 通過 for passing.

**Full-width punctuation inside Chinese sentences**: ，。、：；？！（）「」
Half-width punctuation belongs only between two Latin words, which in a paper
means inside citations, bibliography entries, and listings. Two LaTeX-specific
consequences, since the source is not plain text:

- Type 「」 as the characters themselves. Backtick-and-quote input (` `` '' `)
  is Latin quoting and comes out as “ ”.
- Type the Chinese ellipsis as ⋯⋯, not `\ldots`, which sets the Latin
  three-dot form on the baseline.

**Keep the half-width space at every CJK/Latin boundary** (§8). That rule is
`be-human-v1`'s too; it is repeated here because it also moves line breaks.

**Abstracts attract AI tone more than any other part of a paper.** Cut
「本文旨在深入探討」「隨著⋯⋯的蓬勃發展」「綜上所述」「具有重要的意義」. State
what was built, what was measured, and what the number was. The 150–250 word
budget in §3 is not the constraint; the padding is.

## 10. Bibliography

- Numbered in citation order. `\cite{key}` gives `[1]`; punctuation follows the
  bracket.
- `thebibliography` **prints its own "References" heading** — adding
  `\section*{References}` gives you two.
- Wrap in `\begingroup\raggedright\small … \endgroup`, or the narrow column
  stretches the entries. `xurl` breaks long URLs.
- `\balance` (from `preprint`) must sit in what will be the **first column of
  the last page**. Issued in the second column it silently does nothing. Look
  at the unbalanced output first, then place it. It also interacts badly with
  floats and footnotes near the end.
- For mixed-script bibliographies prefer `biblatex` with `style=ieee` and the
  `biber` backend; classic BibTeX is 8-bit and mishandles Unicode sorting.
- Chinese references: keep the author name un-inverted (陳大文, not 大文, 陳),
  and append `(in Chinese)` after the entry.

## 11. Build and verify

```bash
latexmk -lualatex -interaction=nonstopmode main.tex
```

No TeX installed? `scripts/build.ps1 main.tex` compiles in a TeX Live container
with the machine's own fonts mounted, and prints the log counts below.

`latexmk` handles the reruns and the BibTeX/biber pass. Without it, a single
pass leaves `??` cross-references and an empty bibliography — run
`lualatex`, `bibtex`, `lualatex`, `lualatex`.

On Overleaf the magic comment is ignored: set Menu → Compiler → LuaLaTeX by
hand. The Noto CJK fonts are already installed there.

Then read the log, in this order:

| Signal | Meaning |
|---|---|
| `Missing character` | glyph silently dropped from the PDF — font is wrong |
| `Font shape … undefined` | a face was substituted; bold or italic CJK is fake |
| `Overfull \hbox` in the bibliography | `\raggedright` wrapper missing |
| `Too many unprocessed floats` | add `\FloatBarrier` |
| `LaTeX Warning: There were undefined references` | just run again |

`references/troubleshooting.md` maps each error to its fix.

---

## Reference files

- `references/template.tex` — complete verified document. Copy the preamble.
- `references/troubleshooting.md` — error → cause → fix.
- `scripts/check-fonts.ps1`, `scripts/check-fonts.sh` — report which candidate
  families are installed before you waste a build.
- `scripts/build.ps1` — containerised LuaLaTeX build for machines with no TeX
  distribution; mounts the host fonts so the build sees the real environment.
