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
#
# Root is needed for /dev/uinput (the driver), NOT for the shell. The shell is
# dropped back to the invoking user — see as_user below for why that matters.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ATTACH=0
[ "${1:-}" = "--attach" ] && ATTACH=1

# The tier needs root for /dev/uinput, but the SHELL must still run as the
# invoking user. Two reasons, and the second is the one that matters:
#
#  - build/run-desktop.sh expects to be invoked by the user in *both* seat
#    modes; it escalates internally for the bits that need it (the direct-mode
#    DRM open). Its $XDG_RUNTIME_DIR guard refuses a runtime dir it does not
#    own (per-user now: /tmp/xdg-starling-<uid>). Back when the dir was one
#    shared name, running the whole tier under sudo left it belonging to the
#    real user while the script was root, and the shell never started at all:
#    "run-desktop: /tmp/xdg-starling is not a directory owned by root — refusing".
#    The tier reported only "the shell did not start", one file away from the
#    cause.
#  - Running the shell as root is the configuration CLAUDE.md warns about at
#    length: third-party clients then run as root too, which both invents
#    failures (Chromium's SUID sandbox, dconf in a root-owned XDG_RUNTIME_DIR)
#    and hides real ones (the portal claiming its name on the wrong bus). A
#    functional tier that does not exercise the unprivileged path the .deb ships
#    is worth much less, and its third-party-app checks cannot be trusted.
#
# Same idiom as test/run.sh, which drops back for the Swift steps.
as_user() {
    if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
        sudo -u "$SUDO_USER" -H -- "$@"
    else
        "$@"
    fi
}

CATALOG_DIR="${TMPDIR:-/tmp}/starling-test-catalog"
RECORDS_DIR="${TMPDIR:-/tmp}/starling-test-records"
# The fixture catalog and records dir describe the shell THIS SCRIPT starts.
# An attached shell was started by something else (usually the packaged GDM
# session) and reads the real /var/lib/starling/installed.d — exporting the
# fixture paths anyway made the checks look for records in a directory the
# attached session never writes: app-install landed gimp in the real records
# dir, the shell lit it up, and the check still failed with ENOENT on
# /tmp/starling-test-records/gimp.app. Attach mode tests the session as it
# is, fixture-free.
if [ "$ATTACH" -eq 0 ]; then
    rm -rf "$CATALOG_DIR" "$RECORDS_DIR"
    mkdir -p "$CATALOG_DIR" "$RECORDS_DIR"
    cp "$REPO"/registry/catalog.d/*.app "$CATALOG_DIR/"
    cp "$REPO"/test/fixtures/*.app "$CATALOG_DIR/"
    chmod 0755 "$CATALOG_DIR" "$RECORDS_DIR"
    # The shell writes app records here (app-install), and it no longer runs as
    # root — so root-owned 0755 would make every install check fail on EACCES
    # rather than on anything the test is about.
    if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
        chown -R "$SUDO_USER" "$CATALOG_DIR" "$RECORDS_DIR"
    fi
    export STARLING_CATALOG_DIR="$CATALOG_DIR"
    export STARLING_APP_RECORDS="$RECORDS_DIR"
fi

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
    # The shell runs as $SUDO_USER (as_user below), so its runtime dir —
    # per-user since the two-user lockout fix — carries that uid.
    rm -f "/tmp/xdg-starling-$(id -u "${SUDO_USER:-$(id -un)}")/wayland-0.lock"
    # run-desktop.sh re-stages, and it now does so as the invoking user. A
    # previous `sudo build/run-desktop.sh` (or `sudo build/stage.sh`) leaves
    # .stage root-owned, and staging then dies on "Permission denied" from
    # rm(1) — nothing to do with this tier. Hand it back rather than fail.
    STAGE="${STARLING_STAGE:-$REPO/.stage}"
    if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ -e "$STAGE" ] &&
       [ "$(stat -c '%U' "$STAGE" 2>/dev/null)" != "$SUDO_USER" ]; then
        echo "handing $STAGE back to $SUDO_USER (left root-owned by an earlier sudo run)"
        chown -R "$SUDO_USER" "$STAGE"
    fi
    echo "starting the desktop with the fixture catalog"
    # sudo -u scrubs the environment, so the two fixture vars have to be handed
    # over explicitly rather than exported. STARLING_SEAT_MODE and
    # LIBSEAT_BACKEND are forwarded only when set to something non-empty: they
    # are read with a bare getenv() downstream, where "" is not the same as
    # unset (see the env-knob trap in CLAUDE.md).
    # A 15s screensaver timeout so the idle check can actually wait one out.
    # The shipped default is ten minutes; every other check would finish long
    # before it fired, and the idle check would have nothing to observe.
    as_user env STARLING_CATALOG_DIR="$CATALOG_DIR" \
                STARLING_APP_RECORDS="$RECORDS_DIR" \
                STARLING_SCREENSAVER_IDLE=15 \
                ${STARLING_SEAT_MODE:+STARLING_SEAT_MODE="$STARLING_SEAT_MODE"} \
                ${LIBSEAT_BACKEND:+LIBSEAT_BACKEND="$LIBSEAT_BACKEND"} \
                "$REPO/build/run-desktop.sh" \
        > "${TMPDIR:-/tmp}/starling-functional.log" 2>&1 &
    SHELL_PID=$!
    for _ in $(seq 1 60); do
        grep -q "listening on wayland" \
            "${TMPDIR:-/tmp}/starling-functional.log" 2>/dev/null && break
        sleep 2
    done
    if ! pgrep -x DesktopShellApp >/dev/null; then
        # Surface the reason here rather than only naming the log. run-desktop.sh
        # refuses on its own line for several ordinary conditions — GPU still
        # held, no seat, a runtime dir it does not own — and "the shell did
        # not start" alone sent one debugging session to the wrong file.
        echo "the shell did not start — see ${TMPDIR:-/tmp}/starling-functional.log" >&2
        tail -3 "${TMPDIR:-/tmp}/starling-functional.log" 2>/dev/null | sed 's/^/    /' >&2
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
