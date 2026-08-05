#!/usr/bin/env bash
# Guest step 4: build the framework + shell + the packaged apps, then stage.
set -euxo pipefail
TC="$HOME/.local/share/swiftly/toolchains/6.2.4"
export PATH="$TC/usr/bin:$PATH"
REPO="$HOME/dev/starling-build/starling-desktop"
cd "$REPO"

# Ubuntu 26.04 ships libxml2.so.16 only; the toolchain's libFoundationXML.so
# wants libxml2.so.2. Its RUNPATH is $ORIGIN, so a symlink beside it is enough
# (no system-wide change).
[ -e "$TC/usr/lib/swift/linux/libxml2.so.2" ] || \
    ln -s /usr/lib/x86_64-linux-gnu/libxml2.so.16 "$TC/usr/lib/swift/linux/libxml2.so.2"

swift --version

# Ubuntu 26.04 workaround. Every Starling target uses C++ interop, so the
# clang importer compiles Foundation's C shim in C++ mode; its
# `#include <math.h>` then lands on libstdc++'s C++ wrapper, which pulls
# <cmath> in textually while the prebuilt `std` module already contains it —
# clang sees every overload twice: "cmath:100: redefinition of 'acos'".
# Predefining the wrapper's include guard stops that textual pull, and
# force-including glibc's math.h keeps the C declarations in every TU (this is
# what libstdc++'s own _GLIBCXX_INCLUDE_NEXT_C_HEADERS path would have done).
SWIFT_FLAGS="-Xcc -D_GLIBCXX_MATH_H -Xcc -include -Xcc /usr/include/math.h"

# The shell (pulls in sdk/ = the FlutterSwift framework port as a dependency).
time swift build -c release --package-path shell $SWIFT_FLAGS

# The five apps the .deb ships, each its own SwiftPM package.
for a in SettingsApp FileExplorerApp TerminalApp CalculatorApp AppStoreApp; do
    time swift build -c release --package-path "apps/$a" $SWIFT_FLAGS
done

# One self-contained tree, the same layout the .deb installs.
build/stage.sh
ls -la .stage/lib | head -30
du -sh .stage
