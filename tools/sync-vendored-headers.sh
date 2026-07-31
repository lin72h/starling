#!/usr/bin/env bash
# Vendor the headers this package needs from outside itself.
#
#   tools/sync-vendored-headers.sh [--check] [engine-root]
#
# Two sources: the engine's public headers, and one header from the Swift
# toolchain (see TOOLCHAIN below).
#
# The framework reaches the engine through three header sets, and all three are
# closed: nothing in them includes anything outside its own directory (the C++
# bridge headers cross-reference by bare filename; embedder.h and fl_drm_view.h
# include only libc). So they can live here, and the package then *compiles* with
# no engine checkout at all — the engine becomes a link-time dependency only.
#
# Deliberately not vendored: swift_runtime_controller.h. It pulls
# flutter/runtime/runtime_controller_interface.h, and from there FML, tonic and
# dart_api.h — a large slice of the engine tree. It is not in the modulemap and
# the framework does not need it; keep it that way.
#
# The manifest for the C++ bridge set is the modulemap itself, so adding a bridge
# header means editing one file rather than two.
#
# --check exits non-zero on drift. Drift matters more than it looks: these
# headers describe the ABI of the libflutter_engine we link against, so a stale
# copy is not a compile error, it is a crash at runtime.
set -euo pipefail

SDK="$(cd "$(dirname "$0")/.." && pwd)"
MODULEMAP="Sources/FlutterSwiftBridgeCxx/include/module.modulemap"

# Single headers to vendor: <engine-relative source>:<destination dir in package>
SINGLES=(
    "flutter/shell/platform/embedder/embedder.h:Sources/FlutterEmbedderBridge/include/engine"
    "flutter/shell/platform/linux_drm/fl_drm_view.h:Sources/FlutterDRMBridge/include/engine"
)
# Where the modulemap-declared C++ bridge headers land.
CXX_DEST="Sources/FlutterSwiftBridgeCxx/include/engine"
CXX_SRC="flutter/lib/ui/swift/include"

CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; shift; fi

# Where the engine checkout is. Explicit argument or $ENGINE_ROOT wins; otherwise
# try the two layouts that exist in practice — an `engine` symlink beside this
# package, and a sibling clone of starling-engine.
ENGINE="${1:-${ENGINE_ROOT:-}}"
if [ -z "$ENGINE" ]; then
    for candidate in "$SDK/../engine" "$SDK/../starling-engine/engine"; do
        if [ -d "$candidate/src/$CXX_SRC" ]; then ENGINE="$candidate"; break; fi
    done
fi
SRC="$ENGINE/src"
if [ -z "$ENGINE" ] || [ ! -d "$SRC/$CXX_SRC" ]; then
    echo "error: no engine bridge headers at ${SRC:-<unset>}/$CXX_SRC" >&2
    echo "       pass the engine root as an argument, or set ENGINE_ROOT" >&2
    exit 1
fi

cd "$SDK"
drift=0
count=0

# one <src> <dest> — copy, or report drift under --check.
one() {
    local from="$1" to="$2"
    if [ ! -f "$from" ]; then
        echo "error: $from is declared but missing from the engine tree" >&2
        exit 1
    fi
    count=$((count + 1))
    if [ "$CHECK" = 1 ]; then
        cmp -s "$from" "$to" || { echo "drift: ${to#Sources/}"; drift=1; }
    else
        mkdir -p "$(dirname "$to")"
        cp "$from" "$to"
    fi
}

# The C++ bridge set, as declared by the modulemap (basenames only).
mapfile -t HEADERS < <(sed -n 's/.*header "\([^"]*\)".*/\1/p' "$MODULEMAP" \
                       | xargs -n1 basename | sort -u)
if [ "${#HEADERS[@]}" -eq 0 ]; then
    echo "error: $MODULEMAP declares no headers" >&2; exit 1
fi
for h in "${HEADERS[@]}"; do
    one "$SRC/$CXX_SRC/$h" "$CXX_DEST/$h"
done

# A header left here after being dropped from the modulemap is dead weight that
# still compiles, so it gets flagged either way.
for stale in $(cd "$CXX_DEST" 2>/dev/null && ls -1 *.h 2>/dev/null || true); do
    printf '%s\n' "${HEADERS[@]}" | grep -qxF "$stale" && continue
    if [ "$CHECK" = 1 ]; then
        echo "stale: $stale is vendored but absent from the modulemap"; drift=1
    else
        rm -f "$CXX_DEST/$stale"; echo "removed stale $stale"
    fi
done

for entry in "${SINGLES[@]}"; do
    rel="${entry%%:*}"; dest="${entry##*:}"
    one "$SRC/$rel" "$dest/$(basename "$rel")"
done

# --- TOOLCHAIN --------------------------------------------------------------
#
# <swift/bridging> is the only toolchain header the bridge headers need, and it
# is the sole reason they used to require an absolute -I into the Swift
# installation. That flag was on *every* Swift target, and .unsafeFlags anywhere
# in a package makes the whole package unusable as a versioned dependency — so
# vendoring this one 11 KB header is what makes FlutterSwift publishable.
#
# All the bridge headers take from it is SWIFT_SHARED_REFERENCE and
# SWIFT_RETURNS_INDEPENDENT_VALUE. Those annotations are what hand the C++
# objects to Swift ARC, so a no-op fallback would compile and then corrupt
# memory; the real definitions have to be here.
#
# The tradeoff: this copy shadows the toolchain's own for anyone building with a
# different Swift version. It is a small, stable compiler-support header, and
# --check catches drift against the toolchain in use — but if a future toolchain
# changes it incompatibly, this is where that breaks.
# Ask the compiler where its resources are rather than guessing from $(which
# swiftc): under swiftly that is a shim binary, so walking up from it lands
# nowhere. runtimeResourcePath is <toolchain>/usr/lib/swift on every platform.
RESOURCE_DIR="$(swiftc -print-target-info 2>/dev/null \
    | sed -n 's/.*"runtimeResourcePath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
if [ -z "$RESOURCE_DIR" ]; then
    echo "error: could not read runtimeResourcePath from 'swiftc -print-target-info'" >&2
    exit 1
fi
TOOLCHAIN_INCLUDE="$(cd "$RESOURCE_DIR/../../include" && pwd)"
one "$TOOLCHAIN_INCLUDE/swift/bridging" \
    "Sources/FlutterSwiftBridgeCxx/include/swift/bridging"

if [ "$CHECK" = 1 ]; then
    if [ "$drift" = 0 ]; then
        echo "vendored headers in sync ($count headers)"
    else
        echo "vendored headers HAVE DRIFTED — run tools/sync-vendored-headers.sh" >&2
    fi
    exit "$drift"
fi

echo "vendored $count headers ($SRC + $TOOLCHAIN_INCLUDE)"
