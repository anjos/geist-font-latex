#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2026 Andre Anjos (github:anjos)
#
# SPDX-License-Identifier: LPPL-1.3c
#
# Regenerates the LaTeX support files from the vendored OTFs and assembles the
# CTAN submission tree.  Requires `autoinst` (CTAN fontools, shipped with TeX
# Live) and `otftotfm` (LCDF TypeTools) on PATH.

set -euo pipefail
cd "$(dirname "$0")"
ROOT=$PWD
BUILD=$ROOT/build
DIST=$ROOT/dist

for tool in autoinst otftotfm tectonic; do
    command -v "$tool" >/dev/null || {
        echo "error: $tool not found on PATH." >&2
        echo "  autoinst  comes with TeX Live (conda-forge: texlive-core)" >&2
        echo "  otftotfm  comes with LCDF TypeTools (brew install lcdf-typetools)" >&2
        echo "  tectonic  builds the documentation (brew install tectonic)" >&2
        exit 1
    }
done

rm -rf "$BUILD" "$DIST"
mkdir -p "$BUILD/work" "$BUILD/tds"

# autoinst drives otftotfm, which resolves the fontools_*.enc encodings through
# kpathsea.  A standalone otftotfm (Homebrew's, say) has no TeX tree to search,
# so we drop the encodings straight into the working directory instead: kpathsea
# looks there first, whoever built it.
curl -fsSL https://mirrors.ctan.org/fonts/utilities/fontools.zip -o "$BUILD/fontools.zip"
unzip -qo "$BUILD/fontools.zip" -d "$BUILD/fontools"
cp "$BUILD"/fontools/fontools/share/*.enc "$BUILD/work/"

# $1: family directory under fonts/, $2: -typeface value, $3: NFSS role
generate() {
    local src=$1 typeface=$2 role=$3
    echo "==> generating $src"
    cp "$ROOT/fonts/$src"/*.otf "$BUILD/work/"
    ( cd "$BUILD/work" && autoinst \
        -target="$BUILD/tds" \
        -vendor=vercel \
        -typeface="$typeface" \
        -encoding=OT1,T1,LY1 \
        -ts1 \
        "$role" \
        "$src"-*.otf )
    rm -f "$BUILD/work"/*.otf
}

generate Geist     geist     -sanserif
generate GeistMono geistmono -typewriter


echo "==> installing OpenType fonts for the fontspec path"
# autoinst does not install the OTFs themselves; XeTeX and LuaTeX need them in
# the tree to resolve \setsansfont{Geist} without an explicit Path=.
for pair in "Geist:geist" "GeistMono:geistmono"; do
    src=${pair%%:*}; typeface=${pair##*:}
    install -d "$BUILD/tds/fonts/opentype/vercel/$typeface"
    cp "$ROOT/fonts/$src"/*.otf "$BUILD/tds/fonts/opentype/vercel/$typeface/"
done

echo "==> installing style files"
# autoinst names its style file after the font family, so it lands as Geist.sty.
# That differs from our geist.sty only in case, which collides on macOS and
# Windows.  Rename it out of the way and let geist.sty be the public entry
# point that dispatches on the engine.
for pair in "Geist:geist" "GeistMono:geistmono"; do
    family=${pair%%:*}; pkg=${pair##*:}
    mv "$BUILD/tds/tex/latex/$pkg/$family.sty" "$BUILD/tds/tex/latex/$pkg/$pkg-nfss.sty"
    sed -i.bak "s/\\\\ProvidesPackage{$family}/\\\\ProvidesPackage{$pkg-nfss}/" \
        "$BUILD/tds/tex/latex/$pkg/$pkg-nfss.sty"
    rm -f "$BUILD/tds/tex/latex/$pkg/$pkg-nfss.sty.bak"
    cp "$ROOT/source/$pkg.sty" "$BUILD/tds/tex/latex/$pkg/"
done

echo "==> documentation"
install -d "$BUILD/tds/doc/fonts/geist"
# Built with tectonic: it is XeTeX, so this also exercises the fontspec branch
# of geist.sty, and it needs no TeX installation of its own.  Compile in a flat
# directory holding the styles and the OTFs, which is what a user without the
# package installed would have.
install -d "$BUILD/doc"
cp "$ROOT/doc/geist-doc.tex" "$ROOT/source"/*.sty "$BUILD/doc/"
cp "$ROOT/fonts"/*/*.otf "$BUILD/doc/"
( cd "$BUILD/doc" && tectonic -X compile geist-doc.tex )
cp "$ROOT/README.md" "$ROOT/fonts/OFL.txt" "$ROOT/doc/geist-doc.tex" \
   "$BUILD/doc/geist-doc.pdf" "$BUILD/tds/doc/fonts/geist/"

echo "==> packaging"
install -d "$DIST"
( cd "$BUILD/tds" && zip -qr "$DIST/geist.tds.zip" . )

# CTAN wants the package tree mirroring the TDS, with the .tds.zip beside it
# rather than inside it.  Everything a user needs is in the tree; the zip is
# what TeX Live's installer consumes.
cp -R "$BUILD/tds" "$DIST/geist"
cp "$ROOT/README.md" "$DIST/geist/"
# the sources that generate the rest, so the package can be rebuilt
install -d "$DIST/geist/source"
cp "$ROOT/build.sh" "$ROOT/source"/*.sty "$ROOT/doc/geist-doc.tex" "$DIST/geist/source/"

( cd "$DIST" && zip -qr geist-ctan.zip geist geist.tds.zip )

echo
echo "done:"
echo "  $DIST/geist-ctan.zip  ($(du -h "$DIST/geist-ctan.zip" | cut -f1))  <- upload this"
echo "  $DIST/geist.tds.zip   ($(du -h "$DIST/geist.tds.zip" | cut -f1))"
echo "  $DIST/geist/          (package tree)"
