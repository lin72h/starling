#!/bin/bash
# Build the Linux/arm64 macOS-binary-compat stack and run the UNMODIFIED Mach-O
# probe through it.
#
#   ./build.sh           L2 — render via the Flutter engine (Swift CompatHost)
#   ./build.sh --stub    L1 — host stub that just prints the JSON view tree
#
# Artifacts (build/):
#   libcompat_host.so  — the host the loader dlopens for swiftui_compat_run/_update
#                        (Swift Flutter host for L2, or the C print-stub for L1)
#   libSwiftUI.so      — reconstructed SwiftUI module (SHARED, unchanged Swift
#                        sources; Foundation-only; compat C symbols left undefined,
#                        resolved at dlopen from libcompat_host.so)
#   machold            — the Mach-O loader/runner
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-l2}"
TOOLCHAIN="$HOME/.local/share/swiftly/toolchains/6.2.4"
SWIFT="$TOOLCHAIN/usr/bin/swift"
SWIFTC="$TOOLCHAIN/usr/bin/swiftc"
CLANG="$TOOLCHAIN/usr/bin/clang"
SWIFT_RT="$TOOLCHAIN/usr/lib/swift/linux"
UI_SRC="../SwiftUIShim/Sources/SwiftUI"
COMBINE_SRC="../SwiftUIShim/Sources/Combine"
ENGINE_OUT="../../engine/src/out/host_debug"

mkdir -p build

if [ "$MODE" = "--stub" ] || [ "$MODE" = "stub" ]; then
    echo "==> [L1] host stub (libcompat_host.so) — prints JSON, no Flutter"
    "$CLANG" -shared -fPIC -o build/libcompat_host.so host/host_stub.c -ldl
else
    echo "==> [L2] Swift Flutter host (libcompat_host.so)"
    ( cd host-swift && "$SWIFT" build )
    cp host-swift/.build/debug/libCompatHost.so build/libcompat_host.so
    # rpaths to the engine/glfw are baked in by the package link; run.sh also sets
    # LD_LIBRARY_PATH with absolute paths as the robust fallback.
fi

echo "==> reconstructed Combine (libCombine.so) — module literally named Combine (7Combine… ABI)"
"$SWIFTC" -emit-library -emit-module -module-name Combine -enable-library-evolution \
  -o build/libCombine.so -emit-module-path build/Combine.swiftmodule \
  "$COMBINE_SRC/Combine.swift" \
  -Xlinker --allow-shlib-undefined -Xlinker --unresolved-symbols=ignore-all \
  -Xlinker -rpath -Xlinker "\$ORIGIN" \
  -Xlinker -rpath -Xlinker "$SWIFT_RT"

echo "==> reconstructed SwiftUI (libSwiftUI.so) — shared sources; compat symbols left undefined"
"$SWIFTC" -emit-library -module-name SwiftUI -enable-library-evolution \
  -I build -L build -lCombine \
  -Xcc -fmodule-map-file=../SwiftUIShim/Sources/CGCompatShims/include/module.modulemap \
  -o build/libSwiftUI.so \
  "$UI_SRC/SwiftUI.swift" "$UI_SRC/Gallery.swift" "$UI_SRC/Gradient.swift" "$UI_SRC/MakeView.swift" "$UI_SRC/FoundationShims.swift" "$UI_SRC/Reflect.swift" "$UI_SRC/FlutterBridge.swift" "$UI_SRC/StateObject.swift" \
  -Xlinker --allow-shlib-undefined -Xlinker --unresolved-symbols=ignore-all \
  -Xlinker -rpath -Xlinker "\$ORIGIN" \
  -Xlinker -rpath -Xlinker "$SWIFT_RT"

echo "==> loader (machold)"
# --export-dynamic: put machold's own C symbols (e.g. swiftui_compat_dispatch, which it
# defines to route AppKit button taps to ObjC target/action) into .dynsym so the
# dlopened libcompat_host.so binds to machold's definition (main-exe wins), with RTLD_NEXT
# forwarding to libSwiftUI's for the tier-1 Swift path.
"$CLANG" -O1 -g -o build/machold loader/machold.c -ldl \
  -Wl,--export-dynamic \
  -Wl,-rpath,"\$ORIGIN" -Wl,-rpath,"$SWIFT_RT"

echo "==> done ($MODE). Artifacts in build/:"
ls -1 build/
echo "Run:  ./run.sh"
