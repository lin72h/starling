#!/bin/sh
# Compiles the runtime-effect shaders in this directory to SkSL .iplr
# bundles, which the shell loads with FragmentProgram(data:backend:.skSL).
# The .iplr outputs are committed (and staged by build/stage.sh) — re-run
# this after editing a .frag.
#
# impellerc comes prebuilt from the engine checkout; point
# STARLING_ENGINE_OUT at a different out dir (e.g. host_debug) to
# override, mirroring shell/Package.swift.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../../../.." && pwd)"
OUT="${STARLING_ENGINE_OUT:-$REPO/engine/src/out/host_release}"
INCLUDE="$REPO/engine/src/flutter/impeller/compiler/shader_lib"
for f in "$DIR"/*.frag; do
    # impellerc insists on writing the intermediate SPIR-V somewhere real
    # (atomic write + rename, so /dev/null fails) — scratch it and drop it.
    "$OUT/impellerc" --sksl --iplr \
        --include="$INCLUDE" \
        --input="$f" --sl="$f.iplr" --spirv="$f.spirv.tmp"
    rm -f "$f.spirv.tmp"
    echo "compiled ${f##*/} -> ${f##*/}.iplr"
done
