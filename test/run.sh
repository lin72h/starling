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

# sdk/ has three XCTest targets, and they do not build on Ubuntu 26.04: the
# `-include /usr/include/math.h` workaround this project needs for the
# ubuntu24.04-built 6.2.4 toolchain (see docs/BUILDING.md) collides with
# <cmath> while the compiler builds swift-testing's own _Testing_Foundation
# module, long before it reaches our code. Opt-in rather than skipped
# silently, and opt-in rather than a permanent red — a suite that is always
# failing for a known reason is a suite people stop reading.
if [ "$SDK" = 1 ]; then
    step "unit tests: sdk"
    (cd "$REPO/sdk" && as_user "$SWIFT" test 2>&1 \
        | grep -vE "libxml2.so.2: no version information" \
        | grep -E "Executed [0-9]+ tests|error:|failed" | tail -5) \
        || fails=$((fails + 1))
else
    step "unit tests: sdk — SKIPPED"
    echo "  does not build on 26.04 (toolchain <cmath> clash vs swift-testing);"
    echo "  run with --sdk to see it, or on a 24.04 toolchain."
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
