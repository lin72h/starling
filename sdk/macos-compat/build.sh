#!/bin/bash
# Build the SwiftUI binary-compat shim (SPM) into build/SwiftUI.framework, ready to
# interpose under an unmodified macOS SwiftUI binary via DYLD_FRAMEWORK_PATH.
#
# The real sources live in SwiftUIShim/ (an SPM package depending on flutter_swift):
#   Sources/SwiftUI/      — reconstructed SwiftUI module (Foundation-only, lib-evolution)
#   Sources/FlutterHost/  — renders the tree via the Flutter engine (imports Flutter/AppKit)
set -euo pipefail
cd "$(dirname "$0")"

echo "==> swift build (SwiftUIShim → libSwiftUIShim.dylib)"
( cd SwiftUIShim && swift build )

FW=build/SwiftUI.framework
rm -rf "$FW"; mkdir -p "$FW/Versions/A"
cp SwiftUIShim/.build/debug/libSwiftUIShim.dylib "$FW/Versions/A/SwiftUI"
ln -sf A "$FW/Versions/Current"
ln -sf Versions/Current/SwiftUI "$FW/SwiftUI"
# The engine's libswift_bridge.dylib has a relative './' install_name; rewrite our
# reference to @rpath (we carry an rpath to the engine out dir).
install_name_tool -change ./libswift_bridge.dylib @rpath/libswift_bridge.dylib "$FW/Versions/A/SwiftUI"

echo "==> symbol coverage vs probe/Hello's imports"
xcrun dyld_info -imports probe/Hello 2>/dev/null | awk '{print $2}' | grep '^_\$s7SwiftUI' | sort -u > build/needed.txt
xcrun nm -g -U "$FW/Versions/A/SwiftUI" 2>/dev/null | awk '{print $NF}' | grep '^_\$s7SwiftUI' | sort -u > build/exported.txt
echo "    SwiftUI symbols: $(comm -12 build/needed.txt build/exported.txt | wc -l | tr -d ' ')/$(wc -l < build/needed.txt | tr -d ' ')"

echo "==> built $FW/Versions/A/SwiftUI  (install_name: $(otool -D "$FW/Versions/A/SwiftUI" | tail -1))"
echo "Run:  DYLD_FRAMEWORK_PATH=\"\$PWD/build\" ./probe/Hello"
