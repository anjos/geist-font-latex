# Repository instructions

## CTAN identity

- The CTAN package and release archive are named `geist-font`; its submission
  directory and CTAN archive location remain `geist`.
- The public LaTeX packages remain `geist` and `geistmono`; do not rename their
  `.sty` files, NFSS families, font files, map files, or TeX-facing commands.
- Documentation must distinguish the `geist-font` CTAN distribution from the
  `geist` and `geistmono` LaTeX packages.

## CTAN archive

- Build and upload only the flat CTAN tree, with one top-level `geist/`
  directory and the file-type directories `doc/`, `latex/`,
  `opentype/`, `type1/`, `tfm/`, `vf/`, `enc/`, `map/`, and `source/`.
- Do not create, mention, bundle, or publish a `.tds.zip` archive.
- Keep `build.sh` and `verify.sh` in the flat tree's `source/` directory.
- `verify.sh` must test the generated flat tree in a throwaway TeX tree with
  pdfLaTeX, XeLaTeX, and LuaLaTeX.

## CTAN submission metadata

- Use `geist-font` as the package ID and `/fonts/geist` as its location.
- Use the renamed repository URLs:
  - Repository: `https://github.com/anjos/geist-font-latex`
  - Bugs: `https://github.com/anjos/geist-font-latex/issues`
  - Announce: `https://github.com/anjos/geist-font-latex/releases`
- Omit the Home URL so that no URL is used more than once.
- Preserve the upstream identification as `vercel/geist-font` v1.7.2, with
  Geist 1.800 and Geist Mono 1.700, unmodified and with no Reserved Font Name.

## Releases and commits

- A GitHub release must publish `geist-font.zip` as its CTAN archive asset;
  an up-to-date standalone documentation PDF may also be published.
- Never publish generated `.tds.zip` or legacy `geist-ctan.zip` assets.
- Execute repository commits with `wt step commit`, not `git commit`.
