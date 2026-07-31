#!/usr/bin/env bash
# Turn the engine's static archives into a SwiftPM artifactbundle a third
# party can consume as a versioned dependency.
#
#   tools/make-static-engine.sh [--debug|--release] [outdir]
#
# Requires two engine targets (shell/platform/embedder and
# shell/platform/linux BUILD.gn in the engine repo):
#
#   ninja -C engine/src/out/host_debug \
#       flutter/shell/platform/embedder:flutter_engine_static_library \
#       flutter/shell/platform/linux:flutter_linux_gtk_static
#
# The first is everything libflutter_engine.so links (embedder + Swift bridge
# + DRM view); the second is the GTK embedder (FlView/FlEngine), kept
# separate in GN because merging it with the engine's libcxx objects at the
# archive level would duplicate them.
#
# WHY THE SYMBOL SURGERY. The shared library gets its discipline from a
# linker version script (embedder_exports.lst): thousands of objects in, ~500
# symbols out. An archive is never linked, so --version-script does not apply
# and every internal symbol stays global — 60k+ of them, including the
# engine's vendored copies of freetype, expat and libjpeg.
#
# That is not a link error. It is worse. A consumer that also uses system
# freetype links fine and runs fine, having silently bound to the engine's
# vendored copy instead of the system one — measured, not theorised. Hand a
# FT_Face across that boundary to a library built against system freetype and
# the struct layouts disagree.
#
# The fix is two steps, in this order, applied to each archive:
#
#   1. ld -r --whole-archive   partial-link every member into ONE object, so
#                              internal cross-references bind now. Skipping
#                              this and localizing the archive directly breaks
#                              it: sibling members can no longer see each other.
#   2. objcopy --keep-global-symbols   demote everything outside the allowlist
#                              to local, reproducing what the version script
#                              does for the .so.
#
# The engine object keeps embedder_exports.lst's list; the GTK object keeps
# fl_* (its whole public API — upstream exports everything from the shared
# GTK library too). The GTK object's private copies of fml/common symbols go
# local, so they cannot collide with the engine object's at final link.
#
# COST: each result is a single object, so the linker can no longer drop
# unused archive members. Consumers should build with --gc-sections, which
# more than recovers it (54 MB -> 29 MB on the test binary).
set -euo pipefail

SDK="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$SDK/.." && pwd)"

CONFIG=debug
case "${1:-}" in
    --debug)   CONFIG=debug;   shift ;;
    --release) CONFIG=release; shift ;;
esac
OUT="${1:-$SDK/.build/static-engine}"

E="${FLUTTER_SWIFT_ENGINE_OUT:-$REPO/engine/src/out/host_$CONFIG}"
[ -d "$E" ] || E="$REPO/starling-engine/engine/src/out/host_$CONFIG"
ENGINE_AR="$E/obj/flutter/shell/platform/embedder/libflutter_engine_static_library.a"
GTK_AR="$E/obj/flutter/shell/platform/linux/libflutter_linux_gtk_static.a"
EXPORTS="$(dirname "$(dirname "$E")")/flutter/shell/platform/embedder/embedder_exports.lst"

for f in "$ENGINE_AR" "$GTK_AR"; do
    if [ ! -f "$f" ]; then
        echo "error: no static archive at $f" >&2
        echo "       build both: ninja -C $E flutter/shell/platform/embedder:flutter_engine_static_library flutter/shell/platform/linux:flutter_linux_gtk_static" >&2
        exit 1
    fi
done
[ -f "$EXPORTS" ] || { echo "error: no export allowlist at $EXPORTS" >&2; exit 1; }

mkdir -p "$OUT"

# Each archive becomes ONE self-contained object. They cannot be merged into
# a single partial link — both carry fml/common/libcxx objects (the GTK
# archive is deliberately self-contained, see its GN target) and ld -r
# rejects the duplicate strong definitions. Separately, each object binds its
# own copies; after localization the duplicates are all local and coexist.
# --force-group-allocation resolves COMDAT groups during the partial link:
# left to the final link, discard-the-duplicate-group collides with
# localization ("defined in discarded section").
one_object() {
    echo "==> partial-linking $(ar t "$1" | wc -l) objects from $(basename "$1")"
    ld -r --force-group-allocation --whole-archive "$1" -o "$2"
}

ENGINE_O="$OUT/engine_combined.o"
GTK_O="$OUT/gtk_combined.o"
one_object "$ENGINE_AR" "$ENGINE_O"
one_object "$GTK_AR" "$GTK_O"

# Translate embedder_exports.lst's globs into the concrete symbol list objcopy
# wants. Deriving it from the same file the .so uses keeps one source of truth:
# a symbol added to the allowlist is exported by both builds. The GTK object
# keeps the fl_* glob, matching the everything-public shared GTK library.
echo "==> deriving keep-lists"
python3 - "$EXPORTS" "$ENGINE_O" "$OUT/keep-engine.txt" <<'PY'
import re, subprocess, sys
exports, obj, out = sys.argv[1], sys.argv[2], sys.argv[3]

globs = []
for line in open(exports):
    line = line.split('#')[0].strip()
    if not line or line in ('{', '};') or line.startswith(('global:', 'local:')):
        continue
    globs.append(line.rstrip(';').strip())
# 'local: *' means everything unmatched is hidden; the '*' entry is not a keep rule.
globs = [g for g in globs if g != '*']
pattern = re.compile('|'.join('(?:%s)' % re.escape(g).replace(r'\*', '.*') for g in globs) + '$')

syms = set()
nm = subprocess.run(['nm', '--defined-only', obj], capture_output=True, text=True).stdout
for line in nm.splitlines():
    parts = line.split()
    if len(parts) >= 3 and parts[1] in 'TWDBRV' and pattern.match(parts[2]):
        syms.add(parts[2])
open(out, 'w').write('\n'.join(sorted(syms)) + '\n')
print(f"    engine: {len(globs)} globs -> {len(syms)} exported symbols")
PY
nm --defined-only "$GTK_O" | awk '$2 ~ /[TWDBRV]/ && $3 ~ /^fl_/ {print $3}' \
    | sort -u > "$OUT/keep-gtk.txt"
echo "    gtk: fl_* -> $(wc -l < "$OUT/keep-gtk.txt") exported symbols"

localize() {  # <in.o> <keep.txt> <out.o>
    local before after
    before=$(nm --defined-only "$1" | grep -cE ' [TWDBRV] ')
    objcopy --keep-global-symbols="$2" "$1" "$3"
    after=$(nm --defined-only "$3" | grep -cE ' [TWDBRV] ')
    echo "    $(basename "$3"): global symbols $before -> $after"
}
echo "==> localizing everything else"
localize "$ENGINE_O" "$OUT/keep-engine.txt" "$OUT/engine_localized.o"
localize "$GTK_O" "$OUT/keep-gtk.txt" "$OUT/gtk_localized.o"

RESULT="$OUT/libFlutterEngineStatic.a"
rm -f "$RESULT"
ar rcs "$RESULT" "$OUT/engine_localized.o" "$OUT/gtk_localized.o"
rm -f "$ENGINE_O" "$GTK_O"

for s in FT_Init_FreeType XML_ParserCreate jpeg_start_decompress; do
    n=$(nm --defined-only "$RESULT" | grep -cE " [TWD] $s\$" || true)
    [ "$n" = 0 ] && echo "  contained: $s" || echo "  WARNING: $s still global"
done

# --- the artifactbundle -------------------------------------------------------
#
# SE-0482 (SwiftPM 6.2): a staticLibrary binaryTarget. The module is
# deliberately empty — the archive only has to LINK; every declaration
# consumers compile against comes from this package's own targets
# (FlutterSwiftBridgeCxx, FlutterEmbedderBridge, FlutterGTKBridge), which is
# also what keeps the C++ bridge outside the C-interface-only restriction.
ENGINE_VERSION=$(sed -n 's/^engine_version = "\(.*\)"/\1/p' "$E/args.gn" | head -1)
BUNDLE="$OUT/FlutterEngineStatic.artifactbundle"
TRIPLE_DIR="$BUNDLE/linux-x86_64"
rm -rf "$BUNDLE"
mkdir -p "$TRIPLE_DIR/include"
cp "$RESULT" "$TRIPLE_DIR/"

cat > "$TRIPLE_DIR/include/FlutterEngineStatic.h" <<'EOF'
// The engine as a static archive. Intentionally declares nothing: consumers
// compile against the FlutterSwift package's own headers; this module exists
// so SwiftPM links the archive.
EOF
cat > "$TRIPLE_DIR/include/module.modulemap" <<'EOF'
module FlutterEngineStatic {
    header "FlutterEngineStatic.h"
}
EOF
cat > "$BUNDLE/info.json" <<EOF
{
    "schemaVersion": "1.0",
    "artifacts": {
        "FlutterEngineStatic": {
            "type": "staticLibrary",
            "version": "${ENGINE_VERSION:-unknown}",
            "variants": [
                {
                    "path": "linux-x86_64/libFlutterEngineStatic.a",
                    "supportedTriples": ["x86_64-unknown-linux-gnu"],
                    "staticLibraryMetadata": {
                        "headerPaths": ["linux-x86_64/include"],
                        "moduleMapPath": "linux-x86_64/include/module.modulemap"
                    }
                }
            ]
        }
    }
}
EOF

ZIP="$OUT/FlutterEngineStatic.artifactbundle.zip"
rm -f "$ZIP"
(cd "$OUT" && zip -qr "$(basename "$ZIP")" "$(basename "$BUNDLE")")

echo
echo "  $RESULT ($(du -h "$RESULT" | cut -f1))"
echo "  $ZIP ($(du -h "$ZIP" | cut -f1))"
echo "  checksum: $(cd "$SDK" && swift package compute-checksum "$ZIP")"
