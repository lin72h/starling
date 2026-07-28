#!/usr/bin/env bash
# Stand up a desktop with the test fixture catalog, run the functional checks,
# and tear it down.
#
#   sudo test/functional.sh              full run (starts and stops the shell)
#   sudo test/functional.sh --attach     run against a shell already up
#
# Needs a free GPU: stop any display manager first (`sudo systemctl stop gdm`).
#
# The fixture catalog is a COPY of registry/catalog.d plus test/fixtures/*.app,
# handed to the shell through STARLING_CATALOG_DIR. The shipped catalog is
# never modified, and the fake app never reaches a real install.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ATTACH=0
[ "${1:-}" = "--attach" ] && ATTACH=1

CATALOG_DIR="${TMPDIR:-/tmp}/starling-test-catalog"
RECORDS_DIR="${TMPDIR:-/tmp}/starling-test-records"
rm -rf "$CATALOG_DIR" "$RECORDS_DIR"
mkdir -p "$CATALOG_DIR" "$RECORDS_DIR"
cp "$REPO"/registry/catalog.d/*.app "$CATALOG_DIR/"
cp "$REPO"/test/fixtures/*.app "$CATALOG_DIR/"
chmod 0755 "$CATALOG_DIR" "$RECORDS_DIR"

export STARLING_CATALOG_DIR="$CATALOG_DIR"
export STARLING_APP_RECORDS="$RECORDS_DIR"

SHELL_PID=""
cleanup() {
    if [ -n "$SHELL_PID" ]; then
        echo "stopping the shell"
        pkill -x DesktopShellApp 2>/dev/null
        sleep 2
    fi
    rm -rf "$CATALOG_DIR" "$RECORDS_DIR" /tmp/starling-selftest
}
trap cleanup EXIT INT TERM

if [ "$ATTACH" = 0 ]; then
    if pgrep -x DesktopShellApp >/dev/null; then
        echo "a shell is already running — use --attach, or stop it first" >&2
        exit 2
    fi
    rm -f /tmp/xdg-starling/wayland-0.lock
    echo "starting the desktop with the fixture catalog"
    "$REPO/build/run-desktop.sh" > "${TMPDIR:-/tmp}/starling-functional.log" 2>&1 &
    SHELL_PID=$!
    for _ in $(seq 1 60); do
        grep -q "listening on wayland" \
            "${TMPDIR:-/tmp}/starling-functional.log" 2>/dev/null && break
        sleep 2
    done
    if ! pgrep -x DesktopShellApp >/dev/null; then
        echo "the shell did not start — see ${TMPDIR:-/tmp}/starling-functional.log" >&2
        exit 1
    fi
    sleep 6   # let the first frame and the app registry settle
else
    pgrep -x DesktopShellApp >/dev/null || {
        echo "--attach given but no shell is running" >&2; exit 2; }
    echo "note: attaching to a shell that was NOT started with the fixture"
    echo "      catalog — the install/remove check will be skipped."
fi

python3 "$REPO/test/functional.py" "${@:2}"
status=$?
exit $status
