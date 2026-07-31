#!/usr/bin/env bash
# Starling test suite.
#
#   test/run.sh              static checks + unit tests   (~2s, no GPU)
#   test/run.sh --build      also compile every package and the .deb
#   test/run.sh --sdk        also run sdk/ tests (see the caveat below)
#   test/run.sh --functional also run the live-desktop checks
#                            (needs root and a free GPU — stop the display
#                            manager first; delegates to test/functional.sh)
#
# The default tier is the one meant to run on every change: it needs no
# compositor, no GPU and no network, and it targets the failure mode that has
# actually cost this project time — two places that must agree, silently
# disagreeing. See test/lint.py for what that means concretely.
#
# Not covered here (see the tiers in the release checklist): driving a live
# desktop, installing real vendor apps, and the VM install/login gate.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUILD=0
SDK=0
FUNCTIONAL=0
for arg in "$@"; do
    case "$arg" in
        --build)      BUILD=1 ;;
        --sdk)        SDK=1 ;;
        --functional) FUNCTIONAL=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

fails=0
step() {
    echo
    echo "── $1 ─────────────────────────────────────────────────────"
}

# The functional tier needs root (/dev/uinput), but `swift` lives in the
# invoking user's swiftly toolchain and root cannot see it — running the whole
# gate under sudo would otherwise skip every Swift step in silence, which is
# how it first reported PASS on tests that never ran.
as_user() {
    if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
        sudo -u "$SUDO_USER" -H -- "$@"
    else
        "$@"
    fi
}

# ...and sudo does not carry the user's PATH either, so `swift` has to be
# resolved by absolute path or the Swift steps silently find nothing to run.
SWIFT="$(command -v swift 2>/dev/null || true)"
if [ -z "$SWIFT" ] && [ -n "${SUDO_USER:-}" ]; then
    SWIFT="$(eval echo "~$SUDO_USER")/.local/share/swiftly/toolchains/*/usr/bin/swift"
    SWIFT="$(ls -1 $SWIFT 2>/dev/null | head -1)"
fi
if [ -z "$SWIFT" ]; then
    echo "warning: no swift toolchain found — Swift steps will fail" >&2
    SWIFT=swift
fi

step "static checks"
python3 "$REPO/test/lint.py" || fails=$((fails + 1))

step "unit tests: registry"
(cd "$REPO/registry" && as_user "$SWIFT" test 2>&1 \
    | grep -vE "libxml2.so.2: no version information" \
    | grep -E "Executed [0-9]+ tests|error:|failed") || fails=$((fails + 1))

# sdk/'s test targets need two things on Ubuntu 26.04 that a plain `swift test`
# does not give them. Both come from the same root: the 6.2.4 toolchain is an
# ubuntu24.04 build, and under C++ interop 26.04's libstdc++ 15 headers make
# Foundation's _CStdlib.h pull <cmath> textually against the prebuilt std module
# ("redefinition of 'acos'"). docs/BUILDING.md has the full write-up.
#
#  1. swift-testing ships Testing, _Testing_Foundation and _TestDiscovery as
#     *textual* .swiftinterface only — XCTest, by contrast, ships a binary
#     .swiftmodule. An interface has to be recompiled in the importing target's
#     context, and ours are C++-interop, so that rebuild hits the clash before
#     ever reaching our code. Compiling them once here, outside C++ interop,
#     yields binary modules the test build consumes as-is, so no rebuild happens.
#     This is unavoidable even for an all-XCTest target: SwiftPM's generated test
#     runner opens with `#if canImport(Testing) import Testing #endif`.
#
#  2. The compat flags have to reach *every* frontend invocation, not just our
#     targets. SwiftPM generates the runner and the test-discovery module itself,
#     and those carry none of a target's swiftSettings while still inheriting C++
#     interop — so the package-level .unsafeFlags cannot cover them. Passing the
#     flags through -Xswiftc does.
#
# Keep these flags in step with `glibcMathCompat` in sdk/Package.swift.
SDK_TESTING_CFLAGS=(-Xcc -D_GLIBCXX_MATH_H -Xcc -include -Xcc /usr/include/math.h)
# Each one has to be introduced by its own -Xswiftc, so build the list rather
# than trying to prefix the array in place (that yields one word per flag, with
# the space embedded, and swift silently treats it as an unknown argument).
SDK_TEST_XFLAGS=()
for _f in "${SDK_TESTING_CFLAGS[@]}"; do SDK_TEST_XFLAGS+=(-Xswiftc "$_f"); done

# Build binary .swiftmodule files for the interface-only swift-testing modules.
# Idempotent: skipped entirely once the cache is populated.
prebuild_swift_testing() {
    local out="$1"
    [ -f "$out/Testing.swiftmodule" ] && return 0
    local res
    res="$(as_user "${SWIFT}c" -print-target-info 2>/dev/null \
           | sed -n 's/.*"runtimeResourcePath": *"\([^"]*\)".*/\1/p' | head -1)"
    [ -n "$res" ] || { echo "  could not locate the Swift resource dir" >&2; return 1; }
    local triple="x86_64-unknown-linux-gnu"
    mkdir -p "$out"
    # _TestDiscovery and _Testing_Foundation first: Testing imports them.
    for m in _TestDiscovery _Testing_Foundation Testing; do
        local iface="$res/linux/$m.swiftmodule/$triple.swiftinterface"
        [ -f "$iface" ] || continue
        as_user "${SWIFT}c" -frontend -compile-module-from-interface \
            -target "$triple" -module-name "$m" -I "$out" \
            -o "$out/$m.swiftmodule" "$iface" 2>&1 | grep -E "error:" && return 1
    done
    return 0
}

if [ "$SDK" = 1 ]; then
    step "unit tests: sdk"
    PREBUILT="$REPO/sdk/.build/swift-testing-prebuilt"
    if prebuild_swift_testing "$PREBUILT"; then
        (cd "$REPO/sdk" && as_user "$SWIFT" test \
            -Xswiftc -I -Xswiftc "$PREBUILT" \
            "${SDK_TEST_XFLAGS[@]}" 2>&1 \
            | grep -vE "libxml2.so.2: no version information" \
            | grep -E "Executed [0-9]+ tests|error:|failed" | tail -5) \
            || fails=$((fails + 1))
    else
        echo "  FAIL  could not prebuild swift-testing modules"
        fails=$((fails + 1))
    fi
else
    step "unit tests: sdk — SKIPPED"
    echo "  run with --sdk (needs a one-off swift-testing module prebuild on 26.04)."
fi

if [ "$BUILD" = 1 ]; then
    step "build: shell + apps"
    for pkg in shell apps/*/; do
        [ -f "$REPO/$pkg/Package.swift" ] || continue
        name=$(basename "$pkg")
        out=$(cd "$REPO/$pkg" && as_user "$SWIFT" build -c release 2>&1)
        if [ $? -eq 0 ]; then
            echo "  ok    $name"
        elif echo "$out" | grep -q "no such module 'AppKit'"; then
            # A macOS-only package (DSATool) on Linux. Let the compiler say so
            # rather than pattern-matching the sources: `import AppKit` inside
            # an `#if os(macOS)` is normal here — the shell, BlueScreenApp and
            # FlutterDemoApp all have one — and a source grep skips those too,
            # which quietly stops testing the shell.
            echo "  skip  $name (macOS-only on this platform)"
        else
            echo "  FAIL  $name"
            echo "$out" | grep -E "error:" | head -3 | sed 's/^/        /'
            fails=$((fails + 1))
        fi
    done

    step "package"
    if as_user "$REPO/build/package-desktop.sh" /tmp/starling-test-pkg \
            >/dev/null 2>&1; then
        echo "  ok    .deb builds"
    else
        echo "  FAIL  .deb"
        fails=$((fails + 1))
    fi
fi

if [ "$FUNCTIONAL" = 1 ]; then
    step "functional (live desktop)"
    if [ "$(id -u)" -ne 0 ]; then
        echo "  needs root for /dev/uinput — re-run with sudo"
        fails=$((fails + 1))
    else
        "$REPO/test/functional.sh" || fails=$((fails + 1))
    fi
fi

echo
if [ "$fails" -eq 0 ]; then
    echo "PASS"
    exit 0
fi
echo "FAIL — $fails step(s)"
exit 1
