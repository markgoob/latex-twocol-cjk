# Examples

Complete documents written with the skill, kept here so that the template is
exercised by something longer than its own two-page demo. CI assembles each one
against the *current* `references/template.tex` and runs the same log gate the
template must pass, so a template change that breaks a real document fails
before it merges.

| Example | What it is | Output |
|---|---|---|
| `skill-intro/` | An introduction to the skill itself: contents, the three-layer document structure, the design decisions in the preamble and the failure each prevents, the Chinese source and prose rules, verification. Chinese body, English and Chinese abstracts, TikZ figures including a two-panel `figure*`, three tables. | `skill-intro.pdf` |

## Layout of an example

```
examples/<name>/
  body.tex          the document-specific part: metadata, overrides, title, body
  main.tex          body.tex with the shared preamble in front; compiles on its own
  <name>.pdf        the rendered output, committed
```

`body.tex` is what a person actually writes. `main.tex` is generated:

```bash
sh examples/assemble.sh skill-intro
cd examples/skill-intro && latexmk -lualatex -interaction=nonstopmode main.tex
```

`assemble.sh` copies `references/template.tex` up to the `% --- TITLE & AUTHORS`
marker and appends `body.tex` — the same recipe SKILL.md gives for starting a
document. It anchors the marker at line start and takes the last match, so a
comment that mentions the marker cannot cut the preamble short (that happened
once).

Without a local TeX installation, `scripts/build.ps1 examples/skill-intro/main.tex`
builds it in a container with the host's fonts mounted.

## Adding one

1. Create `examples/<name>/body.tex`. Start it with the document-specific
   `\hypersetup`, any `\titleformat` overrides, `\title`, `\author`, `\date{}`,
   then `\begin{document}` and the rest. Keep each Chinese paragraph on one
   source line.
2. `sh examples/assemble.sh <name>` and build. Fix until
   `scripts/log-gate.sh examples/<name>/main.log` reports five zeros.
3. Commit `body.tex`, the generated `main.tex`, and the PDF as `<name>.pdf`.
   `main.pdf` stays ignored.
