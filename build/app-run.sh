#!/bin/sh
# app-run.sh — run a third-party Linux app in the Starling app runtime.
#
# Starling ships a deliberately minimal userland, but third-party apps
# (Chrome, VS Code, …) expect a full Ubuntu/glibc environment — Mesa, GTK,
# fonts, the works. This gives them one: a shared, read-only Ubuntu runtime
# plus a private per-app home, wired to the Starling shell's Wayland display
# and the GPU. The app renders with the runtime's OWN Mesa (guest userspace
# on the host kernel) and hands dma-buf frames to the compositor.
#
# This is a COMPATIBILITY RUNTIME, not a security sandbox. The namespace
# flags below exist only to (a) run the app unprivileged as a normal user
# and (b) let one read-only runtime image serve many apps with separate,
# persistent settings — not to lock anything down.
#
#   RUNTIME  = /var/lib/starling-apps/runtime      (shared Ubuntu userland, ro)
#   HOME     = /var/lib/starling-apps/homes/<name> (per-app, persistent)
#
# Usage:
#   sudo tools/app-run.sh <name> [extra args…]      # a known app (registry)
#   sudo tools/app-run.sh <name> -- <cmd> [args…]   # any command in the runtime
#
#   sudo tools/app-run.sh chrome                    # launch Chrome
#   sudo tools/app-run.sh chrome https://news.ycombinator.com
#   sudo tools/app-run.sh sh -- /bin/bash           # a shell in the runtime
#
# Building the runtime once (debootstrap; roadmap: make this a Bazel-built
# EROFS image shipped in Starling):
#   sudo debootstrap --variant=minbase noble /var/lib/starling-apps/runtime
#   echo 'deb http://archive.ubuntu.com/ubuntu noble main universe' \
#       > /var/lib/starling-apps/runtime/etc/apt/sources.list
#   sudo mount --bind /proc /var/lib/starling-apps/runtime/proc
#   sudo mount --bind /dev  /var/lib/starling-apps/runtime/dev
#   sudo chroot /var/lib/starling-apps/runtime apt-get update
#   sudo chroot /var/lib/starling-apps/runtime apt-get install -y \
#       --no-install-recommends ca-certificates fonts-liberation \
#       libgl1-mesa-dri libegl1 libgles2 libegl-mesa0 mesa-utils
#   sudo chroot /var/lib/starling-apps/runtime apt-get install -y \
#       --no-install-recommends /tmp/google-chrome-stable_current_amd64.deb
#   sudo umount /var/lib/starling-apps/runtime/dev /var/lib/starling-apps/runtime/proc

set -eu

RUNTIME="${STARLING_APP_RUNTIME:-/var/lib/starling-apps/runtime}"
HOMES="${STARLING_APP_HOMES:-/var/lib/starling-apps/homes}"
XDG_DIR="${STARLING_XDG_DIR:-/tmp/xdg-starling}"
SOCKET="${STARLING_WAYLAND:-wayland-0}"
# Follow the shell's actual DPI (the shell exports FLUTTER_DRM_DPI to every
# child, so store-launched apps inherit it); 2.0 matches the shell default.
SCALE="${STARLING_APP_SCALE:-${FLUTTER_DRM_DPI:-2.0}}"

# Starling's xdg-open shim (tools/appbin/) goes FIRST on every app's PATH:
# URL handoffs (Electron shell.openExternal, Qt QDesktopServices, Chromium
# external protocols all exec `xdg-open`) resolve through the app registry
# — web URLs relaunch into `app-run chrome` with the compositor-required
# flags, app deep-link schemes route back to their registry app — instead
# of the host's desktop config launching a bare, broken browser.
# STARLING_APP_RUN tells the shim where app-run itself lives.
SELF="$(readlink -f "$0")"
APPBIN="$(dirname "$SELF")/appbin"
# Packaged install: app-run lives at /usr/bin, the shim dir under
# /usr/lib/starling.
[ -d "$APPBIN" ] || APPBIN=/usr/lib/starling/appbin

# First existing path from a candidate list — the same app lands in
# different places depending on how it was installed (runtime image /opt
# extraction vs the vendor deb's own layout on a host install).
first_of() {
    for _p in "$@"; do
        if [ -x "$_p" ]; then echo "$_p"; return 0; fi
    done
    echo "$1"
}

# The bwrap sandbox + Ubuntu compatibility runtime exist ONLY to give
# third-party apps a full glibc/GTK userland on the sealed Starling image
# (a minimal, read-only, dm-verity root). On any other distro — the dev box
# — the host already provides the app, its libraries, and its AppArmor
# profile, so the sandbox is pure friction (it broke Zoom's embedded CEF and
# has no home for Slack's /usr/lib files). There, run the app directly.
# Starling's image sets ID=starling in /etc/os-release (tools/mkrootfs.sh);
# STARLING_FORCE_SANDBOX=1 overrides for testing the sandbox path off-image.
is_starling_os() {
    [ "${STARLING_FORCE_SANDBOX:-}" = "1" ] && return 0
    grep -qs '^ID=starling' /etc/os-release
}

if [ $# -lt 1 ]; then
    echo "usage: app-run.sh <name> [args…]  |  app-run.sh <name> -- <cmd> [args…]" >&2
    exit 2
fi
NAME="$1"; shift

# ── App registry ─────────────────────────────────────────────────────────
# Resolve a friendly name to the command line to run in the runtime. The
# per-app home is keyed on $NAME. Add entries here as apps are installed.
if [ "${1:-}" = "--" ]; then
    # Explicit command form: app-run.sh <name> -- <cmd> [args…]
    shift
    set -- "$@"
else
    case "$NAME" in
        chrome)
            # Chrome runs with its OWN sandbox fully enabled (namespace
            # zygote + seccomp GPU/renderer sandboxes). bwrap's mounts are
            # nosuid so the setuid helper can never work — the zygote's
            # nested-userns path must succeed; see the BWRAP selection
            # below for the AppArmor arrangement that permits it.
            set -- /opt/google/chrome/chrome \
                --ozone-platform=wayland \
                --no-first-run --no-default-browser-check --use-angle=gl \
                --disable-features=VaapiVideoDecoder,VaapiVideoEncoder \
                --force-device-scale-factor="$SCALE" "$@"
            # Agent CDP endpoint (Murmuration): STARLING_CDP=<agent-id> gives
            # this launch its own profile + a DevTools port (Chrome refuses
            # remote debugging on the default profile dir; a per-agent
            # profile also keeps each agent in its own browser instance).
            # The chosen port lands in <profile>/DevToolsActivePort, which
            # the shell's broker reads from the host side of the app home.
            if [ -n "${STARLING_CDP:-}" ]; then
                set -- "$@" \
                    --user-data-dir="/home/user/.config/chrome-cdp-$STARLING_CDP" \
                    --remote-debugging-port=0
            fi
            ;;
        vscode)
            # Electron, so native Wayland like Chrome — but unlike Chrome its
            # sandbox is switched off: the setuid helper cannot work under
            # bwrap's nosuid mounts and Electron has no nested-userns zygote
            # path to fall back on. Matches the flags the shell's own launch
            # table uses, including the per-socket user-data-dir, which keeps a
            # second shell's instance from adopting the first one's window.
            set -- "$(first_of /usr/share/code/code /usr/bin/code)" \
                --ozone-platform=wayland \
                --no-sandbox --disable-gpu-sandbox \
                --user-data-dir="/tmp/vscode_${WAYLAND_DISPLAY:-wayland-0}" \
                --disable-features=VaapiVideoDecoder,VaapiVideoEncoder \
                --use-angle=gl --password-store=basic \
                --force-device-scale-factor="$SCALE" "$@"
            ;;
        gimp)
            # GTK3, native Wayland. GTK3 tolerates our output metadata where
            # GTK4 does not (see wayland_output.c), so this one just works.
            set -- /usr/bin/env GDK_BACKEND=wayland \
                "$(first_of /usr/bin/gimp /usr/bin/gimp-3.2)" "$@"
            ;;
        zoom)
            # Qt app. ZoomLauncher hardcodes QT_QPA_PLATFORM=xcb (its
            # native wayland path segfaults — abandoned upstream), so
            # zoom runs against the shell's in-tree X11 server on :1
            # (Sources/X11Server, DRI3/Present). The socket dir is bound
            # into the sandbox below.
            #
            # LD_LIBRARY_PATH is REQUIRED, unlike Chrome/Slack which resolve
            # their bundles through $ORIGIN. The zoom binary's RUNPATH is
            # Zoom's own build-machine path (/home/jenkins/agent/workspace/…),
            # which exists nowhere, so the distro package relies on a wrapper
            # script to set the search path. We exec the launcher directly and
            # must supply it ourselves — without this the loader cannot find
            # libQt6QuickControls2.so.6, zoom dies during init, and all you
            # see is Zoom's own "Zoom quit unexpectedly" reporter.
            # WAYLAND_DISPLAY must be UNSET, not merely overridden. Zoom
            # probes it and takes its native-Wayland path when present —
            # the path upstream abandoned — and dies instantly, before
            # printing a single line. Same visible symptom as the missing
            # library above ("Zoom quit unexpectedly"), different cause;
            # both have to be fixed for zoom to start.
            #
            # THIRD failure with the SAME symptom, and nothing here can fix
            # it: a corrupt ~/.zoom crashes the main UI process on startup.
            # Zoom's engine still comes up and its crash reporter renders, so
            # you get a black main window plus "Zoom quit unexpectedly" and it
            # looks exactly like a compositor bug. It isn't. Move ~/.zoom aside
            # and relaunch — that alone took zoom from black to pixel-perfect
            # here. Check for it before suspecting the X server.
            # AUDIO / DO NOT INSTALL pulseaudio-utils. Zoom crashes (SIGSEGV
            # during audio init) whenever `pactl` is on PATH on a box that runs
            # PipeWire without a native PulseAudio daemon — the common Ubuntu
            # 25.10/26.04 setup here. With pactl ABSENT, Zoom logs "no pactl and
            # pacmd found", skips audio, and runs fine; with pactl present it
            # segfaults, and a working PULSE_SERVER does NOT save it (verified:
            # crashes either way once pactl exists). So: leave pactl uninstalled
            # for Zoom to work at all. The tradeoff is no Zoom audio until this
            # PipeWire-vs-pactl crash is worked around per-app (bwrap-masking
            # /usr/bin/pactl for Zoom only, once host-direct grows that hook).
            #
            # XDG_SESSION_TYPE=X11 is what unlocks SCREEN SHARE. Per the Arch
            # wiki: "To enable screen share on Xorg, you must change the
            # session type to X11". Zoom reads it to decide whether to offer
            # the X11 capture path at all; env -i above means nothing sets it
            # for us, so without this line sharing is silently unavailable
            # even though our XShmGetImage capture works fine.
            #
            # QT_SCALE_FACTOR matches the shell's FLUTTER_DRM_DPI — on a 4K
            # panel Zoom's Qt UI is otherwise rendered at 1:1 and comes out
            # tiny. Honour an explicit override if the caller set one.
            set -- /usr/bin/env -u WAYLAND_DISPLAY \
                DISPLAY=:1 QT_QPA_PLATFORM=xcb \
                XDG_SESSION_TYPE=X11 \
                QT_SCALE_FACTOR="${QT_SCALE_FACTOR:-${FLUTTER_DRM_DPI:-1.7}}" \
                LD_LIBRARY_PATH=/opt/zoom:/opt/zoom/Qt/lib \
                /opt/zoom/ZoomLauncher "$@"
            ;;
        slack)
            # Electron/Chromium app — a native Wayland client like Chrome.
            # Runtime image: /opt/slack extraction; host vendor deb installs
            # /usr/lib/slack.
            set -- "$(first_of /opt/slack/slack /usr/lib/slack/slack)" \
                --ozone-platform=wayland --use-angle=gl \
                --force-device-scale-factor="$SCALE" "$@"
            ;;
        telegram)
            # Qt6 app with NATIVE Wayland (unlike Zoom's xcb). Runs on the
            # shell's Wayland — Qt6 over our X server's GLX stalls, and the
            # primary-selection compositor fix stopped it crashing on init.
            # Official self-contained tarball extracted to /opt/telegram.
            set -- /usr/bin/env QT_QPA_PLATFORM=wayland \
                /opt/telegram/Telegram "$@"
            ;;
        intellij)
            # IntelliJ IDEA on the JetBrains Runtime's Wayland toolkit.
            #
            # WLToolkit is opt-in: JBR still defaults to XToolkit, and left to
            # itself IDEA runs against our X server, where two things go wrong.
            # Java's AWT init blocks on XI1 ListInputDevices, and Java2D picks
            # the XRender pipeline our server only stubs out — so the X path
            # additionally needs -Dsun.java2d.xrender=false and still lays the
            # window out wrong. Native Wayland is the better path here: it is a
            # wl_shm (software) client, which the compositor composites through
            # its CPU upload path.
            #
            # Set on the command line, not via JAVA_TOOL_OPTIONS: the IDE warns
            # on startup about that variable overriding its own *.vmoptions.
            set -- "$(first_of /opt/idea/bin/idea /usr/bin/idea)" \
                -Dawt.toolkit.name=WLToolkit "$@"
            ;;
        blender)
            # Heavy OpenGL app (GHOST windowing). Auto-selects the Wayland
            # backend when WAYLAND_DISPLAY is set (host-direct sets it).
            # Official self-contained build at /opt/blender; Ubuntu archive
            # package at /usr/bin/blender (host installs via app-install).
            set -- "$(first_of /opt/blender/blender /usr/bin/blender)" "$@"
            ;;
        teams)
            # teams-for-linux: the community Electron Teams client
            # (Microsoft discontinued the native Linux Teams in 2022; the
            # official path is now the PWA in a browser). Native Wayland
            # like Chrome/Slack. Self-contained deb extraction at /opt.
            # Sandbox off for the same reason as VS Code: Electron needs its
            # setuid helper, which cannot work under bwrap's nosuid mounts (nor
            # when the client runs as root in dev mode), and it has no
            # nested-userns zygote to fall back on the way Chrome does. Without
            # this it dies on "The SUID sandbox helper binary ... is not
            # configured correctly" before showing a window.
            set -- /opt/teams-for-linux/teams-for-linux \
                --ozone-platform=wayland --use-angle=gl \
                --no-sandbox --disable-gpu-sandbox \
                --force-device-scale-factor="$SCALE" "$@"
            ;;
        discord)
            # Official Electron app, but shipped as a bootstrapper: the
            # launcher downloads the real app to ~/.config/discord/app-*/ on
            # first run, then execs it with our args. Native Wayland like
            # Chrome/Slack. Host vendor deb installs /usr/share/discord.
            set -- "$(first_of /usr/bin/discord /opt/discord/discord /usr/share/discord/Discord)" \
                --ozone-platform=wayland --use-angle=gl \
                --force-device-scale-factor="$SCALE" "$@"
            ;;
        spotify)
            # Chromium/CEF app — native Wayland like Chrome. Runtime image:
            # /opt/spotify; the vendor apt repo installs /usr/share/spotify.
            set -- "$(first_of /opt/spotify/spotify /usr/share/spotify/spotify)" \
                --ozone-platform=wayland --use-angle=gl \
                --force-device-scale-factor="$SCALE" "$@"
            ;;
        *)
            echo "app-run: unknown app '$NAME'." >&2
            echo "known apps: chrome, vscode, gimp, zoom, slack, telegram, blender, teams, discord, spotify" >&2
            echo "or run any command:  app-run.sh $NAME -- <cmd> [args…]" >&2
            exit 2
            ;;
    esac
fi

# ── Host-direct launch (non-Starling distro) ─────────────────────────────
# Not on the sealed image → skip bwrap and the Ubuntu runtime entirely; the
# host has everything. Run the resolved command as the LOGIN user (app-run
# is invoked via sudo from the root shell; Chrome/Slack must not run as
# root) wired to the shell's Wayland/X11 display AND its session bus.
# DBUS is load-bearing: apps read desktop settings (color-scheme, accent)
# from the shell's xdg-desktop-portal at startup. On a dev box the inherited
# host bus (/run/user/UID/bus) has a portal that HANGS on Settings.ReadAll,
# which deadlocks GTK4 apps during init — point them at the shell's bus
# ($XDG_DIR/bus, started by run-shell-gpu.sh) whose portal answers.
DBUS_ADDR="unix:path=$XDG_DIR/bus"
if ! is_starling_os; then
    if [ "$(id -u)" -eq 0 ]; then
        LOGIN_USER="${SUDO_USER:-$(stat -c %U "$XDG_DIR" 2>/dev/null || true)}"
        [ -n "${LOGIN_USER:-}" ] || LOGIN_USER="$(id -un 1000 2>/dev/null || echo user)"
        LOGIN_HOME="$(getent passwd "$LOGIN_USER" | cut -d: -f6)"
        LOGIN_UID="$(id -u "$LOGIN_USER" 2>/dev/null || echo 1000)"
        # Audio: env -i + our private XDG_RUNTIME_DIR ($XDG_DIR, not
        # /run/user/UID) hides the PipeWire/PulseAudio socket, which lives under
        # the login user's REAL runtime dir. Point PULSE_SERVER straight at it so
        # libpulse-based apps (Chrome, Slack, Teams) get sound. Only set it when
        # the socket exists.
        #
        # NB Zoom is NOT helped by this — see the zoom recipe's pactl warning.
        PULSE_SOCK="/run/user/$LOGIN_UID/pulse/native"
        [ -S "$PULSE_SOCK" ] && PULSE_ENV="PULSE_SERVER=unix:$PULSE_SOCK" || PULSE_ENV="PULSE_UNSET="
        # env -i: start from a CLEAN environment — this is the host-direct
        # twin of the bwrap path's --clearenv. The invoker is the DRM shell,
        # whose Starling-Mesa env (LD_LIBRARY_PATH, MESA_LOADER_DRIVER_
        # OVERRIDE=zink, VK_ICD_FILENAMES, GBM_BACKENDS_PATH) otherwise
        # leaks through runuser into the app: Chromium's GPU process then
        # dies in a CreateSharedImage crash loop (exit 8704), falls back to
        # software wl_shm rendering, and the window exists but never
        # composites — the app looks like it "didn't launch".
        exec runuser -u "$LOGIN_USER" -- env -i \
            HOME="$LOGIN_HOME" \
            USER="$LOGIN_USER" \
            LOGNAME="$LOGIN_USER" \
            PATH="$APPBIN:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
            LANG="${LANG:-en_US.UTF-8}" \
            XDG_RUNTIME_DIR="$XDG_DIR" \
            "$PULSE_ENV" \
            WAYLAND_DISPLAY="$SOCKET" \
            DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" \
            DISPLAY="${DISPLAY:-:1}" \
            STARLING_APP_RUN="$SELF" \
            "$@"
    else
        # Already the login user (dev invoking app-run directly, or the
        # xdg-open shim relaunching a handoff from inside an app). Keep the
        # caller's env but still scrub the Starling-Mesa vars.
        exec env \
            -u LD_LIBRARY_PATH -u MESA_LOADER_DRIVER_OVERRIDE \
            -u VK_ICD_FILENAMES -u GBM_BACKENDS_PATH \
            PATH="$APPBIN:$PATH" \
            XDG_RUNTIME_DIR="$XDG_DIR" \
            WAYLAND_DISPLAY="$SOCKET" \
            DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" \
            DISPLAY="${DISPLAY:-:1}" \
            STARLING_APP_RUN="$SELF" \
            "$@"
    fi
fi

APP_HOME="$HOMES/$NAME"
mkdir -p "$APP_HOME"

# Store-installed apps: the App Store extracts official .debs (Google
# Chrome, Zoom) into INSTALLED/<id>/ on the writable var partition. The
# runtime is a sealed read-only image, so /opt is reassembled on a
# tmpfs: the runtime's own /opt entries first, then each installed
# app's /opt subtree bound over them (same-name shadows the baked
# copy). bwrap applies mounts in argument order and these are built by
# prepending to "$@", so the loops run store-first, baked second,
# tmpfs last.
INSTALLED="${STARLING_APP_INSTALLED:-/var/lib/starling-apps/installed}"
for d in "$INSTALLED"/*/opt/*/; do
    [ -d "$d" ] || continue
    set -- --ro-bind "${d%/}" "/opt/$(basename "$d")" "$@"
done
for d in "$RUNTIME"/opt/*/; do
    [ -d "$d" ] || continue
    set -- --ro-bind "${d%/}" "/opt/$(basename "$d")" "$@"
done
set -- --tmpfs /opt "$@"

# Chrome's namespace sandbox needs nested userns plus capabilities inside
# its own userns. Ubuntu confines /usr/bin/bwrap's children under
# bwrap//&unpriv_bwrap, which strips those capabilities — that policy
# exists to stop UNPRIVILEGED bwrap bypassing the userns restriction, but
# app-run's bwrap runs as root. Exec a copy from an unprofiled path so
# children stay unconfined and /opt/google/chrome/chrome attaches
# Ubuntu's stock 'chrome' profile (which grants userns) on exec. On the
# Starling image there is no AppArmor and /usr/bin/bwrap is used as-is.
BWRAP=/usr/bin/bwrap
if grep -q '^bwrap ' /sys/kernel/security/apparmor/profiles 2>/dev/null; then
    SB=/var/lib/starling-apps/bin/bwrap
    mkdir -p /var/lib/starling-apps/bin
    cmp -s /usr/bin/bwrap "$SB" 2>/dev/null || cp /usr/bin/bwrap "$SB" 2>/dev/null || true
    [ -x "$SB" ] && BWRAP="$SB"
fi

exec "$BWRAP" \
    --unshare-user \
    --uid 1000 --gid 1000 \
    --unshare-pid \
    --new-session \
    --die-with-parent \
    --ro-bind "$RUNTIME" / \
    --proc /proc \
    --dev /dev \
    --tmpfs /dev/shm \
    --dev-bind /dev/dri /dev/dri \
    --ro-bind /sys /sys \
    --tmpfs /run \
    --dir /run/user/1000 \
    --bind "$XDG_DIR" /run/user/1000 \
    --tmpfs /home \
    --bind "$APP_HOME" /home/user \
    --tmpfs /tmp \
    --ro-bind-try /tmp/.X11-unix /tmp/.X11-unix \
    --clearenv \
    --setenv XDG_RUNTIME_DIR /run/user/1000 \
    --setenv WAYLAND_DISPLAY "$SOCKET" \
    --setenv HOME /home/user \
    --setenv USER user \
    --setenv LOGNAME user \
    --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    --setenv LANG C.UTF-8 \
    "$@"
