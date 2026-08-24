<!--
SPDX-FileCopyrightText: 2026 Andre Anjos (github:anjos)

SPDX-License-Identifier: LPPL-1.3c
-->

# geist-font — LaTeX support for the Geist and Geist Mono typefaces

The `geist-font` CTAN distribution provides the `geist` and `geistmono` LaTeX
packages for [Geist](https://github.com/vercel/geist-font), the sans-serif and
monospaced typeface family designed by Vercel. Both families are covered in all
nine weights (Thin through Black) with matching italics.

The package works with **pdfLaTeX**, **XeLaTeX** and **LuaLaTeX**. Under XeLaTeX
and LuaLaTeX the OpenType fonts are used directly through `fontspec`; under
pdfLaTeX the package uses Type1 fonts and metrics generated from them, because
pdfTeX cannot subset CFF-flavoured OpenType.

## Usage

```latex
\usepackage{geist}      % Geist as the sans-serif family
\usepackage{geistmono}  % Geist Mono as the typewriter family
```

To set Geist as the document's main font:

```latex
\usepackage{geist}
\renewcommand{\familydefault}{\sfdefault}
```

Geist ships nine weights, more than NFSS's traditional series axis exposes. The
usual `\textbf` and `\textit` work as expected, and the additional weights are
reachable through `\fontseries`; see the package documentation for the full
weight table.

## Fonts included

| Family    | Upstream version | Faces                              |
| --------- | ---------------- | ---------------------------------- |
| Geist     | 1.800            | 9 weights + italics (18 faces)     |
| Geist Mono| 1.700            | 9 weights + italics (18 faces)     |

Taken from the upstream `vercel/geist-font` release **v1.7.2**.

Geist Pixel, a set of five decorative display faces in the same upstream
release, is not packaged. It has no weight or shape axis to map onto NFSS and no
obvious use in a document body. Open an issue if you want it.

## License

- The fonts, and everything derived from them (the Type1 fonts, metrics and
  encodings generated during packaging), are licensed under the
  **SIL Open Font License, Version 1.1** — see `OFL.txt`. Geist declares no
  Reserved Font Name.
- The LaTeX support files (`.sty`, `.fd`) and the documentation are licensed
  under the **LaTeX Project Public License, version 1.3c** or later.

## Building from source

Support files are generated with `autoinst` from the CTAN `fontools` package,
which in turn drives `otftotfm` from the LCDF TypeTools. Neither is needed to
*use* the package, only to rebuild it.

```
./build.sh    # regenerate everything into build/ and dist/
./verify.sh   # install the flat dist/geist tree into a throwaway texmf
              # tree and compile with pdflatex, xelatex and lualatex
```

The CTAN upload is `dist/geist-font.zip`. It contains only the flat `geist/`
package tree; TeX Live constructs its installation layout from
that tree.

`build.sh` downloads `autoinst` from the CTAN `fontools` package and needs
`otftotfm` (`brew install lcdf-typetools`) and either `tectonic` or `xelatex`
to build the documentation. `verify.sh` needs a full TeX Live; the easiest way
to get all of it at once is the `texlive/texlive` container:

```
docker run --rm -v "$PWD:/pkg" -w /pkg texlive/texlive:latest ./verify.sh
```

The package is generated in OT1 and T1 only. `autoinst` turns its encoding list
into a `\RequirePackage{fontenc}` call whose last entry becomes the document's
current encoding, and with LY1 in that list every family lacking an LY1 shape —
Computer Modern, so anything still using `\rmfamily` — is silently substituted
with Times. T1 covers the same ground without that side effect.
