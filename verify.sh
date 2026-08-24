#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2026 Andre Anjos (github:anjos)
#
# SPDX-License-Identifier: LPPL-1.3c
#
# Installs the flat dist/geist-fonts package tree into a throwaway texmf tree
# and compiles the documentation with every engine the package claims to
# support. The tree is thrown away so nothing here can be satisfied by accident
# from the working directory or from a real installation.

set -euo pipefail
cd "$(dirname "$0")"
ROOT=$PWD
PACKAGE_ROOT=$ROOT/dist/geist-fonts

[ -d "$PACKAGE_ROOT" ] || { echo "error: run build.sh first" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export TEXMFHOME="$TMP/texmf"
install -d \
    "$TEXMFHOME/tex/latex/geist-fonts" \
    "$TEXMFHOME/fonts/opentype/vercel/geist-fonts" \
    "$TEXMFHOME/fonts/type1/vercel/geist-fonts" \
    "$TEXMFHOME/fonts/tfm/vercel/geist-fonts" \
    "$TEXMFHOME/fonts/vf/vercel/geist-fonts" \
    "$TEXMFHOME/fonts/enc/dvips/geist-fonts" \
    "$TEXMFHOME/fonts/map/dvips/geist-fonts"
cp "$PACKAGE_ROOT"/latex/*    "$TEXMFHOME/tex/latex/geist-fonts/"
cp "$PACKAGE_ROOT"/opentype/* "$TEXMFHOME/fonts/opentype/vercel/geist-fonts/"
cp "$PACKAGE_ROOT"/type1/*    "$TEXMFHOME/fonts/type1/vercel/geist-fonts/"
cp "$PACKAGE_ROOT"/tfm/*      "$TEXMFHOME/fonts/tfm/vercel/geist-fonts/"
cp "$PACKAGE_ROOT"/vf/*       "$TEXMFHOME/fonts/vf/vercel/geist-fonts/"
cp "$PACKAGE_ROOT"/enc/*      "$TEXMFHOME/fonts/enc/dvips/geist-fonts/"
cp "$PACKAGE_ROOT"/map/*      "$TEXMFHOME/fonts/map/dvips/geist-fonts/"
mktexlsr "$TEXMFHOME" >/dev/null

# The Type1 path only works once the map files are registered.  updmap-user
# announces on stderr that it is switching to per-user mappings, which is the
# whole point here, so drop it rather than let it read as a failure.
updmap-user --quiet --enable Map=Geist.map >/dev/null 2>&1
updmap-user --quiet --enable Map=GeistMono.map >/dev/null 2>&1
updmap-user --quiet >/dev/null 2>&1

cp "$ROOT/doc/geist-doc.tex" "$TMP/"
cd "$TMP"

status=0
for engine in pdflatex xelatex lualatex; do
    printf '%-10s ' "$engine"
    if ! command -v "$engine" >/dev/null; then
        echo "SKIP (not installed)"; continue
    fi
    rm -f geist-doc.pdf
    if ! "$engine" -interaction=nonstopmode geist-doc.tex >"$engine.out" 2>&1 \
       || ! "$engine" -interaction=nonstopmode geist-doc.tex >"$engine.out" 2>&1; then
        echo "FAIL (compile); see $TMP/$engine.out"; status=1; continue
    fi
    # a missing face does not fail the run, it silently substitutes: look for it
    if grep -qE "Font shape .* undefined|Font .* not found|not loadable" "$engine.out"; then
        echo "FAIL (font substitution)"
        grep -hE "Font shape .* undefined|Font .* not found" "$engine.out" | head -3
        status=1; continue
    fi
    python3 - "$engine" <<'PY'
import re, sys, zlib
data = open("geist-doc.pdf", "rb").read()
found = set()
for m in re.finditer(rb"stream\r?\n(.*?)endstream", data, re.S):
    for blob in (m.group(1),):
        try: blob = zlib.decompress(blob)
        except Exception: pass
        found.update(re.findall(rb"/BaseFont\s*/([A-Za-z0-9+#-]+)", blob))
names = {n.decode() for n in found}
geist = {n for n in names if "Geist" in n}
subset = {n for n in geist if re.match(r"^[A-Z]{6}\+", n)}
bare = {n.split("+")[-1].replace("-Identity-H", "") for n in geist}
ok = len(geist) > 0 and subset == geist
print(f"{'OK  ' if ok else 'FAIL'} {len(bare)} faces, all subset-embedded"
      if ok else f"FAIL {len(geist)} Geist fonts, {len(geist-subset)} not subset-embedded")
# Medium and Bold must be different faces, not the same one twice
for pair in (("Geist-Medium", "Geist-Bold"),):
    if not set(pair) <= bare:
        print(f"     warning: expected both of {pair}, saw {sorted(bare)[:6]}...")
sys.exit(0 if ok else 1)
PY
    [ $? -eq 0 ] || status=1
done

exit $status
