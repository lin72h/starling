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

# power/ is swift-testing, not XCTest — pure Swift, no C++ interop, so it
# dodges the sdk's swift-testing/26.04 problem described below.
step "unit tests: power"
(cd "$REPO/power" && as_user "$SWIFT" test 2>&1 \
    | grep -vE "libxml2.so.2: no version information" \
    | grep -E "Test run with|error:|failed") || fails=$((fails + 1))

# sdk/'s test targets cannot be run with a plain `swift test` on Ubuntu 26.04:
# the 6.2.4 toolchain is an ubuntu24.04 build, and under C++ interop 26.04's
# libstdc++ 15 headers make Foundation's _CStdlib.h pull <cmath> textually
# against the prebuilt std module ("redefinition of 'acos'"). swift-testing
# ships as a textual .swiftinterface, so it gets recompiled in our interop
# context and hits that before reaching any of our code.
#
# The workaround — prebuild those modules outside interop, and pass the compat
# flags to every frontend invocation — now lives with the framework, in
# sdk/tools/run-tests.sh. Delegate to it rather than keeping a second copy: the
# copy that used to live here hardcoded an x86_64 triple, so on aarch64 it
# matched no interface, prebuilt nothing, and reported success.
if [ "$SDK" = 1 ]; then
    step "unit tests: sdk"
    (cd "$REPO/sdk" && as_user env SWIFT="$SWIFT" ./tools/run-tests.sh 2>&1 \
        | grep -vE "libxml2.so.2: no version information" \
        | grep -E "Test run with [0-9]+ tests|Executed [0-9]+ tests|error:|failed" \
        | tail -5) \
        || fails=$((fails + 1))
else
    step "unit tests: sdk — SKIPPED"
    echo "  run with --sdk (needs a one-off swift-testing module prebuild on 26.04)."
fi

# An app that vendors a prebuilt native library built for another architecture
# cannot link, and nothing in this repo can make it. apps/ImageViewerApp ships an
# x86-64 .deps/pdfium/lib/libpdfium.so, so on arm64 it dies with
# `cannot find -lpdfium` — ld does say "skipping incompatible" first, but that
# scrolls past and the error names a missing library rather than a wrong one.
#
# Skipped by *architecture*, not by name: there is no list of app ids here to
# drift out of step with the registry, and the moment a matching libpdfium.so is
# dropped in, the app builds again with no change to this file. Announced rather
# than silent — a package that stops being built without saying so is how you
# ship a desktop with a missing app.
#
# The host's ELF machine word is read off /bin/true instead of mapping uname -m
# to an ELF name, so this needs no architecture table either.
elf_machine() { readelf -h "$1" 2>/dev/null | sed -n 's/^ *Machine: *//p'; }
HOST_MACHINE="$(elf_machine /bin/true)"

# Prints "<lib> (<its arch>, host is <ours>)" and succeeds when a vendored
# library cannot be linked on this host; fails silently when all of them can.
vendored_arch_mismatch() {
    local lib m
    for lib in "$1"/.deps/*/lib/*.so; do
        [ -f "$lib" ] || continue
        m="$(elf_machine "$lib")"
        [ -n "$m" ] && [ -n "$HOST_MACHINE" ] && [ "$m" != "$HOST_MACHINE" ] && {
            printf '%s (%s, host is %s)\n' "$(basename "$lib")" "$m" "$HOST_MACHINE"
            return 0
        }
    done
    return 1
}

if [ "$BUILD" = 1 ]; then
    step "build: shell + apps"
    for pkg in shell apps/*/; do
        [ -f "$REPO/$pkg/Package.swift" ] || continue
        name=$(basename "$pkg")
        if mismatch=$(vendored_arch_mismatch "$REPO/$pkg"); then
            echo "  skip  $name — vendored $mismatch"
            continue
        fi
        out=$(cd "$REPO/$pkg" && as_user "$SWIFT" build -c release 2>&1)
        # Every package builds on Linux, including the macOS-only ones: they
        # select a placeholder target off macOS (see apps/DSATool/Package.swift)
        # rather than failing to compile. So a build error here is a real one —
        # this used to swallow anything mentioning `no such module 'AppKit'`,
        # which would also have hidden a genuine AppKit leak into a Linux path.
        if [ $? -eq 0 ]; then
            echo "  ok    $name"
        else
            echo "  FAIL  $name"
            echo "$out" | grep -E "error:" | head -3 | sed 's/^/        /'
            fails=$((fails + 1))
        fi
    done

    step "package"
    # Packaging needs ~500 MB (a 227 MB stage, the same again as the package
    # root, then the .deb). /tmp is a tmpfs here and is mounted with usrquota, so
    # on a box where it is small or the user is near their quota this step fails
    # with EDQUOT no matter what the code does. Point it somewhere else rather
    # than lose the release gate to the environment.
    PKG_OUT="${STARLING_PKG_OUT:-/tmp/starling-test-pkg}"
    pkg_err=$(as_user "$REPO/build/package-desktop.sh" "$PKG_OUT" 2>&1 >/dev/null) \
        && pkg_ok=1 || pkg_ok=0
    if [ "$pkg_ok" = 1 ]; then
        echo "  ok    .deb builds"
    else
        echo "  FAIL  .deb"
        # Surfaced, not swallowed: this used to redirect stderr to /dev/null, so
        # a disk-quota failure and a genuine packaging bug looked identical.
        echo "$pkg_err" | grep -E "error|Error|No such file|quota" | head -3 \
            | sed 's/^/        /'
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
