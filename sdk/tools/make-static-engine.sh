#!/usr/bin/env bash
# Turn the engine's static archive into one a third party can safely link.
#
#   tools/make-static-engine.sh [--debug|--release] [outdir]
#
# Requires the engine's flutter_engine_static_library target (added to
# shell/platform/embedder/BUILD.gn in the engine repo):
#
#   ninja -C engine/src/out/host_release flutter_engine_static_library
#
# WHY THIS EXISTS. The shared library gets its discipline from a linker version
# script (embedder_exports.lst): 3.3k objects in, 515 symbols out. An archive is
# never linked, so --version-script does not apply and every internal symbol stays
# global — 63,917 of them, including the engine's vendored copies of freetype,
# expat and libjpeg.
#
# That is not a link error. It is worse. A consumer that also uses system
# freetype links fine and runs fine, having silently bound to the engine's
# vendored copy instead of the system one — measured, not theorised. Hand a
# FT_Face across that boundary to a library built against system freetype and the
# struct layouts disagree.
#
# The fix is two steps, in this order:
#
#   1. ld -r --whole-archive   partial-link every member into ONE object, so
#                              internal cross-references bind now. Skipping this
#                              and localizing the archive directly breaks it:
#                              sibling members can no longer see each other.
#   2. objcopy --keep-global-symbols   demote everything outside the allowlist to
#                              local, reproducing what the version script does for
#                              the .so.
#
# COST: the result is a single object, so the linker can no longer drop unused
# archive members. Consumers should build with --gc-sections, which more than
# recovers it (54 MB -> 29 MB on the test binary).
set -euo pipefail

SDK="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$SDK/.." && pwd)"

CONFIG=release
case "${1:-}" in
    --debug)   CONFIG=debug;   shift ;;
    --release) CONFIG=release; shift ;;
esac
OUT="${1:-$SDK/.build/static-engine}"

E="${FLUTTER_SWIFT_ENGINE_OUT:-$REPO/engine/src/out/host_$CONFIG}"
ARCHIVE="$E/obj/flutter/shell/platform/embedder/libflutter_engine_static.a"
EXPORTS="$REPO/engine/src/flutter/shell/platform/embedder/embedder_exports.lst"

if [ ! -f "$ARCHIVE" ]; then
    echo "error: no static archive at $ARCHIVE" >&2
    echo "       build it: ninja -C $E flutter_engine_static_library" >&2
    exit 1
fi
[ -f "$EXPORTS" ] || { echo "error: no export allowlist at $EXPORTS" >&2; exit 1; }

mkdir -p "$OUT"
COMBINED="$OUT/engine_combined.o"
LOCALIZED="$OUT/engine_localized.o"
RESULT="$OUT/libflutter_engine_static.a"

echo "==> partial-linking $(ar t "$ARCHIVE" | wc -l) objects"
ld -r --whole-archive "$ARCHIVE" -o "$COMBINED"

# Translate embedder_exports.lst's globs into the concrete symbol list objcopy
# wants. Deriving it from the same file the .so uses keeps one source of truth:
# a symbol added to the allowlist is exported by both builds.
echo "==> deriving the keep-list from $(basename "$EXPORTS")"
python3 - "$EXPORTS" "$COMBINED" "$OUT/keep.txt" <<'PY'
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
print(f"    {len(globs)} globs -> {len(syms)} exported symbols")
PY

before=$(nm --defined-only "$COMBINED" | grep -cE ' [TWDBRV] ')
echo "==> localizing everything else"
objcopy --keep-global-symbols="$OUT/keep.txt" "$COMBINED" "$LOCALIZED"
after=$(nm --defined-only "$LOCALIZED" | grep -cE ' [TWDBRV] ')

rm -f "$RESULT"
ar rcs "$RESULT" "$LOCALIZED"
rm -f "$COMBINED"

echo
echo "  $RESULT ($(du -h "$RESULT" | cut -f1))"
echo "  global symbols: $before -> $after"
for s in FT_Init_FreeType XML_ParserCreate jpeg_start_decompress; do
    n=$(nm --defined-only "$LOCALIZED" | grep -cE " [TWD] $s\$" || true)
    [ "$n" = 0 ] && echo "  contained: $s" || echo "  WARNING: $s still global"
done
