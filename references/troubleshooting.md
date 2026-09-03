# Troubleshooting: LuaLaTeX + babel + CJK, two-column

Every entry below was reproduced on TeX Live 2026 (LuaHBTeX 1.24.0) against
Windows-installed fonts. Log excerpts are literal.

---

## E1. `Package babel Error: The bidi method 'basic' is available only in luatex`

**Fatal. No PDF is produced.**

`bidi=basic` is the LuaTeX bidi algorithm. Under XeLaTeX babel raises an error
and stops, so any template that pairs `% !TeX program = xelatex` with
`bidi=basic` cannot build at all.

Fix: build with `lualatex`, and drop the `bidi=` option entirely — an
LTR-only Chinese/English document has no use for it. If you genuinely need RTL
under XeTeX, the value is `bidi=bidi-r`, not `basic`.

The same applies to `onchar=ids fonts`, the per-character font switch this whole
setup rests on: LuaTeX-only. Under XeLaTeX it does not error, it simply never
fires — the main language's font takes the entire document, and the failure is
invisible until someone notices the Latin text is set in a CJK face with no
hyphenation. If you must stay on XeLaTeX, the equivalent is babel 3.97's
`\babelcharclass` / `\babelinterchar`, or the older `ucharclasses` package.

## E2. `fontspec error: The font "Noto Serif CJK TC" cannot be found`

**Fatal.**

Two different naming universes hold the same typeface:

| Source | Family name |
|---|---|
| noto-cjk repo, Linux `fonts-noto-cjk`, Overleaf | `Noto Serif CJK TC` |
| Google Fonts (what a Windows user downloads) | `Noto Serif TC` |

Stock Windows 11 has neither; its in-box Traditional Chinese faces are
`Microsoft JhengHei` (sans), `PMingLiU` / `MingLiU` (serif), `DFKai-SB` (kai).

Fix: use the `\PickFont` chain in `template.tex` rather than one hard-coded
name, and run `scripts/check-fonts.ps1` first.

## E3. Chinese text is visibly thinner than the Latin next to it

**No warning at all. This is the nastiest one.**

Google ships Noto TC as a single variable file. `fc-query NotoSerifTC-VF.ttf`
reports its first named instance as style `ExtraLight,Regular`, weight 40. A
lookup by family name matches that instance, so the body text is set in
ExtraLight.

**Do not diagnose this with `pdffonts`.** Subset names come from the base font's
PostScript name, so a correctly pinned run still reports
`NotoSerifTC-ExtraLight`. The name tells you nothing about the applied axis.

Two diagnostics that do work:

1. Render an explicit `wght=200` and compare file hashes with the unpinned
   render. They come out **byte-identical** — and 200 is the ExtraLight end of
   the axis, so the unpinned lookup demonstrably resolves there.
2. Render the same text with `pdftoppm -gray` and compare ink coverage
   (255 minus mean grey). Two independent harnesses measured, for
   default : `wght=400` : `wght=700`:

   | Harness | Ratio |
   |---|---|
   | 28 pt sample, 150 dpi | 1.00 : 1.28 : 1.72 |
   | Huge sample, 150 dpi | 1.00 : 1.38 : 1.84 |

   Absolute figures depend on sample text, point size, and DPI, so compare
   ratios, not numbers.

Fix: pin the axis. `RawFeature={axis={wght=400}}` for upright, `700` for bold.
Static families ignore the feature without complaint, so the same declaration is
safe whichever font was found. Verified through `\babelfont` as the template
applies it, not just bare `\setmainfont`.

## E4. `Missing character: There is no 中 in font ...`

The glyph is **dropped from the PDF**; the build still exits 0. Since LaTeX
2021 this also appears on the console, but it scrolls past easily.

Causes, in order of likelihood:

1. Only `rm` was declared for the CJK locale, and the character is inside
   `\texttt`, a `Verbatim` block, or a `\sffamily` TikZ node. Declare `sf` and
   `tt` for the CJK locale too.
2. Bare CJK inside math mode. Wrap it: `$P_{\text{尖峰}}$`.
3. The character is outside the font's coverage — rare Han, or CJK Ext-B.
   `MingLiU-ExtB` or `Noto Serif CJK TC` cover more than the TC subsets.

Always finish a build with a grep for `Missing character` in the `.log`.

## E5. Captions read `図 1` / `表 I`, bibliography heading is `参考文献`

The `japanese` babel locale is supplying the caption strings. `babel-ja.ini`
defines `figure = 図`, `table = 表`, `bib = 参考文献`,
`date.long = [y]年[M]月[d]日`. These are Japanese glyph forms — wrong even in
meaning for a Traditional Chinese document, which would use 圖 and 參考文獻.

Fix: main language `english`, secondary `chinese-traditional`. Do not use
`japanese` for Chinese; the zh-Hant locale exists
(`babel-zh-Hant.ini`, `name.babel = chinese-traditional chinese-hant`).

## E6. Captions read `Figure 1:` when the house style says `Fig. 1.`

Nothing produces IEEE caption format by itself. Load `caption` and set it:

```latex
\captionsetup[figure]{name={Fig.}, labelsep=period, font=footnotesize}
\captionsetup[table]{labelsep=newline, textfont=sc, justification=centering,
                     name={TABLE}}
```

## E7. `Section 2` in the text, `II.` in the heading

`titlesec`'s label argument changes only the printed heading. `\ref` reads
`\thesection`, which stays `\arabic` unless you redefine it.

```latex
\renewcommand{\thesection}{\Roman{section}}
\renewcommand{\thesubsection}{\thesection-\Alph{subsection}}
```

## E8. `Font shape 'TU/NotoSerifTC(0)/m/sc' undefined`

CJK has no case, so no CJK font has a small-caps face — and `\scshape` on every
IEEE `\section` asks for one. Harmless (upright is substituted) but noisy.

Fix: map the face back to the same file, `SmallCapsFont={*}`. Same for
`ItalicFont` and `BoldItalicFont` with `FakeSlant=0.2`.

What no setting fixes: in a heading mixing scripts, the Latin half small-caps
and the Chinese half stays upright. For mostly-Chinese headings replace
`\scshape` with `\bfseries` and `\itshape` with `\bfseries`.

## E9. Huge white gaps around floats; text pushed to odd places

Missing `\raggedbottom` after `\begin{document}`. Without it LaTeX stretches
inter-paragraph glue to make both columns end at the same height.

Related: `Too many unprocessed floats` means the float queue overflowed — insert
`\FloatBarrier` or `\clearpage`. `[H]` from the `float` package makes this
worse, not better; do not load `float` at all.

## E10. Last page columns wildly uneven

`\balance` must appear in what will be the **first column of the last page**.
Issued from the second column it does nothing and prints
`Package balance Warning: You have called \balance in second column`, which the
log gate counts. It also misbehaves around floats and footnotes. Compile once
unbalanced and look at the last page: if both columns are already full, leave
`\balance` out; otherwise place it in the first column of that page.

## E11. Two `References` headings

`thebibliography` emits `\section*{\refname}` itself. Adding your own
`\section*{References}` duplicates it.

## E12. Overfull `\hbox` in the bibliography

Narrow columns cannot justify long entries. Wrap the bibliography in
`\begingroup\raggedright\small … \endgroup` and load `xurl` so URLs break.

## E13. `\thanks` footnote vanished

Footnotes generated inside `\twocolumn[\begin{@twocolumnfalse} … ]` are built
outside the main galley and are lost. Put the note in the affiliation lines, or
emit `\footnotetext{...}` after the block.

## E14. `??` cross-references, empty bibliography

One pass is not enough. Use `latexmk -lualatex`, which reruns and calls
bibtex/biber as needed.

## E15. Overleaf fails at `\usepackage{fontspec}`

Overleaf ignores the `% !TeX program` magic comment and defaults to pdfLaTeX.
Menu → Compiler → LuaLaTeX. Its TeX Live already carries the Noto CJK fonts, so
no font setup is needed there.

## E16. `LaTeX Error: File 'balance.sty' not found`

`\balance` lives in the `preprint` bundle, not a package of its own:
`tlmgr install preprint`. `subcaption` likewise comes with `caption`.

## E17. A visible gap in the middle of a Chinese sentence

Not a font problem, and not something babel can fix. TeX turns an end-of-line
into a space during tokenisation, long before `onchar=ids fonts` looks at the
text, so a source line broken between two Han characters prints that space:

```latex
這是一段中文，會在這裡
斷行。          % <- the break prints as a space between 裡 and 斷
```

Fix in the source, not the preamble: join lines whose last character and next
line's first character are **both** Han. Do not join across a Chinese/Latin
boundary or inside a table row — those spaces are wanted (see E18).

An editor's hard-wrap at 80 columns will reintroduce this on every save, so for
Chinese paragraphs either turn wrapping off or keep each paragraph on one line.

## E18. Chinese and Latin words are jammed together

The opposite habit. babel inserts nothing at a script boundary, unlike xeCJK,
so `用Dorico記譜` sets with no breathing room. Type a real half-width space:
`用 Dorico 記譜`. This is the one authoring cost of the babel route, and it is
exactly the case E17's line-joining must leave alone.

## E19. Underfull `\hbox` (badness 10000) on many Chinese lines

Chinese has no interword glue to stretch, so a narrow two-column measure with a
few unbreakable `\texttt{}` identifiers leaves the line-breaker nothing to work
with. Do not reach for `\sloppy`. Widen the inter-character glue on the locale:

```latex
\babelprovide[import, onchar=ids fonts,
              intraspace={0 .22 .10}]{chinese-traditional}
```

The three values are base, stretch, shrink in ems. Keep the base at 0 so normal
lines are unchanged. On a 12-page zh-Hant paper this took badness-10000 underfull
warnings from 26 down to 5.

## E20. `! Undefined control sequence` at `\XeLaTeX`, `\LuaLaTeX` or `\XeTeX`

```
! Undefined control sequence.
<argument> ...ackage: Font selection for \XeLaTeX
```

These logos are not kernel macros; `metalogo` defines them. `\LaTeX` and `\TeX`
are fine. Write the engine names as plain text, or `\usepackage{metalogo}`.
Under `-halt-on-error` this is the first thing that stops a build, so it shows
up before any font problem does.

## E21. `Missing character: There is no 図 (U+56F3) in font "name:Noto Serif TC…"`

Not the naming split of E2 — the font was found. It is a regional subset with a
hole: Google's `Noto Serif TC` carries the Traditional Chinese repertoire and
omits Japanese shinjitai forms such as 図, many simplified forms, and rare Han.
The same log line appears for `Noto Sans TC` when the glyph sits in `\texttt`
or a Verbatim block. The build exits 0 and the character is simply absent from
the page.

Check coverage before relying on a glyph:

```bash
fc-list ':charset=56f3' family      # who has U+56F3?
```

The template handles this automatically: `\PickFont* \CJKFallback` looks for a
wider font (full-repertoire Noto Sans CJK, Microsoft JhengHei, Yu Gothic) and,
when one exists, attaches it to `rm`, `sf` and `tt` through luaotfload:

```latex
\directlua{luaotfload.add_fallback("cjkfallback", {"Microsoft JhengHei:mode=harf;"})}
\babelfont[chinese-traditional]{rm}[..., RawFeature={fallback=cjkfallback}]{Noto Serif TC}
```

Both this and an explicit switch — `\newfontfamily\ja{Microsoft JhengHei}` then
`{\ja 図}` — were tested under babel's `onchar=ids fonts` and both survive it;
the fallback needs no markup in the text. One limit: a fallback glyph inside
bold text renders at the second font's regular weight.

## E22. `Overfull \hbox (36pt too wide)` on a line with `\verb|…|`, or `Underfull` badness 6000–10000 around `\texttt`

```
Overfull \hbox (36.32518pt too wide) in paragraph at lines 334--335
[]\TU/NotoSansMono(0)/m/n/10 \babelprovide[import, onchar=ids fonts]{chinese-
```

Inline `\verb` cannot break. Past roughly 40 characters it overflows a column,
and the lines before it go loose trying to avoid that, which is where the
accompanying `Underfull` comes from. Move the command into a display `Verbatim`
block; a long command may be split over two lines, with an argument starting on
the next line:

```latex
\begin{Verbatim}
\babelprovide[import, onchar=ids fonts]
             {chinese-traditional}
\end{Verbatim}
```

A run of three `\texttt{}` tokens joined by 、 produces the same `Underfull`
without any overflow. Spread the tokens across the sentence instead of listing
them back to back.

## E23. `Package caption Warning: Unused \captionsetup[subfigure]`

The template preamble configures subfigure captions. A document that ends up
with no `subfigure` environment never consumes that setup, and `caption`
reports it — one line, but the log gate counts it. Either keep a subfigure or
delete the `\captionsetup[subfigure]{…}` line from your copy of the preamble.

## E24. `Missing character: There is no ⋯ (U+22EF) in font "name:Noto Serif…"`

The Chinese ellipsis typed in Chinese prose, yet the log names the *Latin*
font. babel's `onchar` assigns characters to a locale by script, and both
ellipsis code points — ⋯ U+22EF and … U+2026 — are script "Common", so they are
never handed to the CJK font. Noto Serif lacks U+22EF entirely, so ⋯ vanishes
from the page; it does have U+2026, which it sets as low Latin dots instead of
the centred form Chinese typography expects.

Fix: route both code points to the Chinese locale. The template does this in
its language block; if you built your own preamble, add:

```latex
\babelcharproperty{"2026}{locale}{chinese-traditional}
\babelcharproperty{"22EF}{locale}{chinese-traditional}
```

Both ellipses then come from the CJK font, centred, with zero `Missing
character`. In English sentences write `\ldots` rather than typing the character,
since a typed … will now also use the CJK glyph.

What does *not* work: attaching the glyph fallback of E21 to the Latin family.
The fallback font has to carry the glyph, and on this machine only the Noto TC
faces do — `fc-list ':charset=22ef' family` lists no Microsoft JhengHei, no
PMingLiU — so the fallback leaves ⋯ missing exactly as before.

---

## Reproducing a clean build without installing TeX

TeX Live in a container, with the host's fonts mounted so the build sees exactly
the families the machine has:

```bash
docker run --rm -v "$PWD:/work" -v "C:/Windows/Fonts:/usr/share/fonts/win:ro" \
  -w /work texlive/texlive:latest-medium \
  sh -c "fc-cache -f >/dev/null; latexmk -lualatex -interaction=nonstopmode main.tex"
```

`tlmgr install preprint titlesec placeins xurl multirow` covers what
`latest-medium` lacks for this template.
