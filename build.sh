#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2026 Andre Anjos (github:anjos)
#
# SPDX-License-Identifier: LPPL-1.3c
#
# Regenerates the LaTeX support files from the vendored OTFs and assembles the
# CTAN submission tree. Downloads `autoinst` from CTAN's fontools package and
# requires `otftotfm` (LCDF TypeTools) on PATH.

set -euo pipefail
cd "$(dirname "$0")"
ROOT=$PWD
BUILD=$ROOT/build
DIST=$ROOT/dist
CTAN_NAME=geist-fonts

for tool in curl unzip otftotfm; do
    command -v "$tool" >/dev/null || {
        echo "error: $tool not found on PATH." >&2
        echo "  otftotfm  comes with LCDF TypeTools (brew install lcdf-typetools)" >&2
        exit 1
    }
done

if command -v tectonic >/dev/null; then
    DOC_COMPILER=tectonic
elif command -v xelatex >/dev/null; then
    DOC_COMPILER=xelatex
else
    echo "error: tectonic or xelatex not found on PATH." >&2
    exit 1
fi

rm -rf "$BUILD" "$DIST"
mkdir -p "$BUILD/work" "$BUILD/tds"

# autoinst drives otftotfm, which resolves the fontools_*.enc encodings through
# kpathsea.  A standalone otftotfm (Homebrew's, say) has no TeX tree to search,
# so we drop the encodings straight into the working directory instead: kpathsea
# looks there first, whoever built it.
curl -fsSL https://mirrors.ctan.org/fonts/utilities/fontools.zip -o "$BUILD/fontools.zip"
unzip -qo "$BUILD/fontools.zip" -d "$BUILD/fontools"
cp "$BUILD"/fontools/fontools/share/*.enc "$BUILD/work/"
AUTOINST=$BUILD/fontools/fontools/bin/autoinst

# OT1 and T1 only, deliberately.  autoinst turns the encoding list into a
# \RequirePackage[...]{fontenc} call, and whichever encoding comes last becomes
# the document's current one.  With LY1 in the list, any family that has no LY1
# shape -- Computer Modern, so anything still using \rmfamily -- gets silently
# substituted with Times.  LY1 is a legacy Y&Y encoding; T1 covers the same
# ground without breaking the roman family.
# $1: family directory under fonts/, $2: -typeface value, $3: NFSS role
generate() {
    local src=$1 typeface=$2 role=$3
    echo "==> generating $src"
    cp "$ROOT/fonts/$src"/*.otf "$BUILD/work/"
    ( cd "$BUILD/work" && "$AUTOINST" \
        -target="$BUILD/tds" \
        -vendor=vercel \
        -typeface="$typeface" \
        -encoding=OT1,T1 \
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
# Build with a XeTeX-based engine, which also exercises the fontspec branch of
# geist.sty. Compile in a flat directory holding the styles and OTFs, like a
# user building without the package installed.
install -d "$BUILD/doc"
cp "$ROOT/doc/geist-doc.tex" "$ROOT/source"/*.sty "$BUILD/doc/"
cp "$ROOT/fonts"/*/*.otf "$BUILD/doc/"
if [ "$DOC_COMPILER" = tectonic ]; then
    ( cd "$BUILD/doc" && tectonic -X compile geist-doc.tex )
else
    ( cd "$BUILD/doc" && \
        xelatex -interaction=nonstopmode -halt-on-error geist-doc.tex >/dev/null && \
        xelatex -interaction=nonstopmode -halt-on-error geist-doc.tex >/dev/null )
fi
cp "$ROOT/README.md" "$ROOT/fonts/OFL.txt" "$ROOT/doc/geist-doc.tex" \
   "$BUILD/doc/geist-doc.pdf" "$BUILD/tds/doc/fonts/geist/"

echo "==> packaging"
install -d "$DIST"

# CTAN expects the generated files in a flat tree with one layer of directories
# grouped by file type. TeX Live turns this tree into its installation layout.
install -d "$DIST/$CTAN_NAME"/{doc,latex,opentype,type1,tfm,vf,enc,map,source}
cp "$ROOT/README.md" "$DIST/$CTAN_NAME/"
cp "$BUILD/doc/geist-doc.pdf" "$ROOT/doc/geist-doc.tex" "$ROOT/fonts/OFL.txt" \
   "$DIST/$CTAN_NAME/doc/"
cp "$BUILD"/tds/tex/latex/*/*             "$DIST/$CTAN_NAME/latex/"
cp "$BUILD"/tds/fonts/opentype/vercel/*/* "$DIST/$CTAN_NAME/opentype/"
cp "$BUILD"/tds/fonts/type1/vercel/*/*    "$DIST/$CTAN_NAME/type1/"
cp "$BUILD"/tds/fonts/tfm/vercel/*/*      "$DIST/$CTAN_NAME/tfm/"
cp "$BUILD"/tds/fonts/vf/vercel/*/*       "$DIST/$CTAN_NAME/vf/"
cp "$BUILD"/tds/fonts/enc/dvips/*/*       "$DIST/$CTAN_NAME/enc/"
cp "$BUILD"/tds/fonts/map/dvips/*/*       "$DIST/$CTAN_NAME/map/"
# how to regenerate all of the above
cp "$ROOT/build.sh" "$ROOT/verify.sh" "$DIST/$CTAN_NAME/source/"

( cd "$DIST" && zip -qr "$CTAN_NAME.zip" "$CTAN_NAME" )

echo
echo "done:"
echo "  $DIST/$CTAN_NAME.zip  ($(du -h "$DIST/$CTAN_NAME.zip" | cut -f1))  <- upload this"
echo "  $DIST/$CTAN_NAME/     (flat CTAN archive tree)"
