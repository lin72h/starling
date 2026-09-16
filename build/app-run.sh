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
XDG_DIR="${STARLING_XDG_DIR:-/tmp/xdg-starling-$(id -u)}"
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

# WHO the app will actually run as, resolved once here because two places
# need the answer: the privilege drop far below, and the Chromium recipes,
# which have to know whether they are about to be launched as root.
#
# On an ordinary install this is moot — the shell runs as the login user and
# there is no root to drop out of. It is not moot on WSL: `wsl` gives you a
# ROOT shell unless the distro was set up with a user account, so the
# documented `starling-session` starts the whole desktop as root. There is
# then nobody to drop to — SUDO_USER is unset and the session runtime dir is
# root's own — so LOGIN_USER resolves to root and the app stays there.
STAY_ROOT=0
if ! is_starling_os && [ "$(id -u)" -eq 0 ]; then
    LOGIN_USER="${SUDO_USER:-$(stat -c %U "$XDG_DIR" 2>/dev/null || true)}"
    [ -n "${LOGIN_USER:-}" ] || LOGIN_USER="$(id -un 1000 2>/dev/null || echo user)"
    if [ "$LOGIN_USER" = root ]; then STAY_ROOT=1; fi
fi
NAME="$1"; shift

# ── Snap apps (Ubuntu App Center ecosystem) ───────────────────────
# A snap is AppArmor-confined and may reach the compositor only at the
# standard @{run}/user/@{uid}/ socket, never Starling's private runtime dir
# — so it runs against the real /run/user/<uid> (where the shell also exposes
# its Wayland socket) and the real user session bus. `snap run` refuses to
# run as root, so under a root dev shell we drop to the login user first; the
# shipped session is already that user. This is its own exec because the
# generic launch path below forces the private runtime dir a snap cannot use.
if [ "$NAME" = "--snap" ]; then
    SNAP_APP="${1:?app-run --snap needs a snap name}"; shift
    # Native Wayland first, X11 as the fallback — both on the shell's own X
    # server (:1), which a confined snap may reach (abstractions/X allows
    # /tmp/.X11-unix/*). GTK and Qt walk these lists themselves. The one
    # case they cannot decide: the snapcraft desktop-launch wrapper forces
    # Qt onto wayland-egl whenever it sees a Wayland socket, plugin or not
    # — VLC ships libqxcb.so and no libqwayland*.so, so it died with
    # "unable to open display". Such a snap gets DISABLE_WAYLAND, the
    # wrapper's own opt-out, and Qt goes to xcb.
    SNAP_ROOT="/snap/${SNAP_APP%%.*}/current"
    SNAP_X11_ONLY=""
    if ls "$SNAP_ROOT"/usr/lib/*/qt5/plugins/platforms/libqxcb.so >/dev/null 2>&1 \
       && ! ls "$SNAP_ROOT"/usr/lib/*/qt5/plugins/platforms/libqwayland*.so >/dev/null 2>&1; then
        SNAP_X11_ONLY=1
    fi
    SNAP_GDK="wayland,x11"; SNAP_QT="wayland;xcb"; SNAP_DISABLE_WL=""
    if [ -n "$SNAP_X11_ONLY" ]; then
        SNAP_QT="xcb"; SNAP_DISABLE_WL=1
    fi
    if ! is_starling_os && [ "$(id -u)" -eq 0 ] && [ "${STAY_ROOT:-0}" -eq 0 ]; then
        LOGIN_HOME="$(getent passwd "$LOGIN_USER" | cut -d: -f6)"
        LOGIN_UID="$(id -u "$LOGIN_USER" 2>/dev/null || echo 1000)"
        exec runuser -u "$LOGIN_USER" -- env -i \
            HOME="$LOGIN_HOME" USER="$LOGIN_USER" LOGNAME="$LOGIN_USER" \
            PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin" \
            LANG="${LANG:-en_US.UTF-8}" \
            XDG_RUNTIME_DIR="/run/user/$LOGIN_UID" \
            WAYLAND_DISPLAY="$SOCKET" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$LOGIN_UID/bus" \
            XDG_SESSION_TYPE=wayland DISPLAY=:1 \
            GDK_BACKEND="$SNAP_GDK" QT_QPA_PLATFORM="$SNAP_QT" \
            ${SNAP_DISABLE_WL:+DISABLE_WAYLAND=1} \
            snap run "$SNAP_APP" "$@"
    fi
    RUID="$(id -u)"
    exec env \
        PATH="/snap/bin:$PATH" \
        XDG_RUNTIME_DIR="/run/user/$RUID" \
        WAYLAND_DISPLAY="$SOCKET" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$RUID/bus" \
        XDG_SESSION_TYPE=wayland DISPLAY=:1 \
        GDK_BACKEND="$SNAP_GDK" QT_QPA_PLATFORM="$SNAP_QT" \
        ${SNAP_DISABLE_WL:+DISABLE_WAYLAND=1} \
        snap run "$SNAP_APP" "$@"
fi

# ── Flatpak apps (Flathub) ───────────────────────────────────────────────
# A Flatpak is sandboxed by bubblewrap and reaches the desktop only through
# what its manifest grants: `--socket=x11` shares /tmp/.X11-unix (our X server
# is X1 there, so DISPLAY=:1 just works), `--socket=wayland` bind-mounts
# $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY — the socket the compositor exposes in the
# real per-user dir; the private session dir is invisible to it, exactly as
# for snaps — and `--socket=pulseaudio` follows PULSE_SERVER. GTK and Qt get
# both backends and pick whichever socket the sandbox actually has. Unlike a
# snap a Flatpak never bundles a graphics driver: Flathub ships Mesa as a
# separate, current runtime extension, which is why VLC from Flathub renders
# on the GPU where the core18 snap fell back to software. Same root handling
# as snaps: a root dev shell drops to the login user first.
if [ "$NAME" = "--flatpak" ]; then
    FLATPAK_APP="${1:?app-run --flatpak needs an app id}"; shift
    # Many sandboxes see no host files at all (Celluloid's can see only
    # ~/Pictures), so a path on the command line is invisible inside and the
    # app silently opens nothing. `--file-forwarding` hands every argument
    # between @@ markers over the document portal — what a launch from the
    # app's own .desktop entry (%U) does — while an app that can already see
    # the path gets it unchanged. Only existing files are wrapped, so options
    # pass through untouched.
    # QT_XCB_GL_INTEGRATION=xcb_egl: a Qt app that lands on the X11 fallback
    # (Zoom is X11-only) otherwise picks Qt's GLX integration, whose config
    # search finds nothing on the in-tree X server and aborts the app with
    # "Could not initialize GLX". Qt's EGL-on-X11 integration works here.
    # (POSIX sh: rotate the positional list instead of building an array.)
    _n=$#; _i=0
    while [ "$_i" -lt "$_n" ]; do
        _a=$1; shift
        if [ -e "$_a" ]; then set -- "$@" @@ "$_a" @@; else set -- "$@" "$_a"; fi
        _i=$((_i + 1))
    done
    if ! is_starling_os && [ "$(id -u)" -eq 0 ] && [ "${STAY_ROOT:-0}" -eq 0 ]; then
        LOGIN_HOME="$(getent passwd "$LOGIN_USER" | cut -d: -f6)"
        LOGIN_UID="$(id -u "$LOGIN_USER" 2>/dev/null || echo 1000)"
        exec runuser -u "$LOGIN_USER" -- env -i \
            HOME="$LOGIN_HOME" USER="$LOGIN_USER" LOGNAME="$LOGIN_USER" \
            PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
            LANG="${LANG:-en_US.UTF-8}" \
            XDG_RUNTIME_DIR="/run/user/$LOGIN_UID" \
            WAYLAND_DISPLAY="$SOCKET" DISPLAY=:1 \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$LOGIN_UID/bus" \
            PULSE_SERVER="unix:/run/user/$LOGIN_UID/pulse/native" \
            XDG_SESSION_TYPE=wayland \
            GDK_BACKEND="wayland,x11" QT_QPA_PLATFORM="wayland;xcb" \
            QT_XCB_GL_INTEGRATION=xcb_egl \
            flatpak run --file-forwarding "$FLATPAK_APP" "$@"
    fi
    RUID="$(id -u)"
    exec env \
        XDG_RUNTIME_DIR="/run/user/$RUID" \
        WAYLAND_DISPLAY="$SOCKET" DISPLAY=:1 \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$RUID/bus" \
        PULSE_SERVER="unix:/run/user/$RUID/pulse/native" \
        XDG_SESSION_TYPE=wayland \
        GDK_BACKEND="wayland,x11" QT_QPA_PLATFORM="wayland;xcb" \
        QT_XCB_GL_INTEGRATION=xcb_egl \
        flatpak run --file-forwarding "$FLATPAK_APP" "$@"
fi

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
            #
            # As ROOT there is no such path: Chrome refuses to start at all
            # ("Running as root without --no-sandbox is not supported"),
            # zygote or no zygote, and exits before it makes a window. That
            # is not a dev-box curiosity — it is what a WSL user gets from
            # the documented `starling-session`, because `wsl` hands out a
            # root shell unless the distro was given a user account. So drop
            # the sandbox only in the case where the alternative is not
            # running: Chrome with no sandbox, or no Chrome. (code and teams
            # below pass these unconditionally; they have no zygote to lose.)
            CHROME_ROOT_FLAGS=""
            if [ "$STAY_ROOT" = 1 ]; then CHROME_ROOT_FLAGS="--no-sandbox"; fi
            set -- /opt/google/chrome/chrome \
                --ozone-platform=wayland \
                --no-first-run --no-default-browser-check --use-angle=gl \
                --disable-features=VaapiVideoDecoder,VaapiVideoEncoder \
                ${CHROME_ROOT_FLAGS} \
                --force-device-scale-factor="$SCALE" "$@"
            # Agent CDP endpoint (Murmuration): STARLING_CDP=<agent-id> gives
            # this launch its own profile + a DevTools port (Chrome refuses
            # remote debugging on the default profile dir; a per-agent
            # profile also keeps each agent in its own browser instance).
            # The chosen port lands in <profile>/DevToolsActivePort, which
            # the shell's broker reads back.
            #
            # WHERE that profile goes depends on which runtime this is, and
            # getting it wrong is silent: /home/user exists only inside the
            # bwrap sandbox on the sealed image, where APP_HOME is bound to
            # it. On a host install — every Ubuntu machine we ship to — there
            # is no /home/user and no way to create one, so Chrome cannot
            # write the profile and DevToolsActivePort never appears. The
            # endpoint then reports "Chrome still starting" forever.
            #
            # So the path is chosen per runtime, and written to a pointer
            # file in the session runtime dir. The broker reads the pointer
            # instead of reconstructing the path, which is what let the two
            # sides disagree in the first place.
            if [ -n "${STARLING_CDP:-}" ]; then
                if is_starling_os; then
                    CDP_GUEST="/home/user/.config/chrome-cdp-$STARLING_CDP"
                    CDP_HOST="$HOMES/$NAME/.config/chrome-cdp-$STARLING_CDP"
                else
                    # Host install: the app runs as the login user with its
                    # own HOME, resolved the same way the exec below does.
                    _cdp_user="${SUDO_USER:-$(stat -c %U "$XDG_DIR" 2>/dev/null || true)}"
                    [ -n "$_cdp_user" ] || _cdp_user="$(id -un)"
                    _cdp_home="$(getent passwd "$_cdp_user" | cut -d: -f6)"
                    [ -n "$_cdp_home" ] || _cdp_home="$HOME"
                    CDP_GUEST="$_cdp_home/.config/chrome-cdp-$STARLING_CDP"
                    CDP_HOST="$CDP_GUEST"
                fi
                set -- "$@" \
                    --user-data-dir="$CDP_GUEST" \
                    --remote-debugging-port=0
                mkdir -p "$XDG_DIR" 2>/dev/null || true
                printf '%s\n' "$CDP_HOST" > "$XDG_DIR/chrome-cdp-$STARLING_CDP.path" 2>/dev/null || true
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
        *)
            echo "app-run: unknown app '$NAME'." >&2
            echo "known apps: chrome, vscode, intellij (third-party apps come from Flathub: --flatpak <id>)" >&2
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

# PRIME render offload: the shell sets STARLING_APP_GPU=discrete for apps
# whose registry record carries Gpu=discrete (and only when a discrete GPU
# exists). Three things must reach the app's FINAL env (same value-or-noop
# shape as PULSE_ENV, because the root branch execs through `env -i` where
# exported vars do not survive):
#
# - STARLING_APP_GPU itself: the compositor reads the CONNECTING client's
#   /proc/<pid>/environ and serves it dmabuf feedback naming the discrete
#   node as main_device. That is what steers Chromium — ozone takes its
#   render node from feedback and ignores every env-side device knob.
# - MESA_LOADER_DRIVER_OVERRIDE=zink + DRI_PRIME=1: Mesa's GL for the
#   discrete node. On the NVIDIA proprietary driver Mesa has no native
#   GL driver, and without the zink override the loader silently falls
#   back to llvmpipe (verified with eglinfo); DRI_PRIME=1 makes zink pick
#   the other GPU's Vulkan device for env-driven clients.
#
# GPU_ENV4 empties DISPLAY for discrete apps (it is assigned AFTER the
# branches' own DISPLAY=:1, and env's later assignment wins): any GL env
# override makes Chromium's GPU probe take a GLX path against the in-tree
# X server, which dies on an xcb assert ("Extra reply data still left in
# queue") and takes the whole browser with it — with or without
# __GLX_VENDOR_LIBRARY_NAME=nvidia, which is why that var is not here.
# Discrete-marked apps are Wayland-native by doctrine; an empty DISPLAY
# just makes XOpenDisplay fail cleanly and the probe skip.
if [ "${STARLING_APP_GPU:-}" = "discrete" ]; then
    GPU_ENV1="STARLING_APP_GPU=discrete"
    GPU_ENV2="MESA_LOADER_DRIVER_OVERRIDE=zink"
    GPU_ENV3="DRI_PRIME=1"
    GPU_ENV4="DISPLAY="
else
    GPU_ENV1="GPU_UNSET1="
    GPU_ENV2="GPU_UNSET2="
    GPU_ENV3="GPU_UNSET3="
    GPU_ENV4="GPU_UNSET4="
fi

if ! is_starling_os; then
    if [ "$(id -u)" -eq 0 ]; then
        # LOGIN_USER was resolved at the top — the Chromium recipes need the
        # same answer, and resolving it twice is how the two would drift.
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
            "$GPU_ENV1" "$GPU_ENV2" "$GPU_ENV3" \
            WAYLAND_DISPLAY="$SOCKET" \
            DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" \
            DISPLAY="${DISPLAY:-:1}" \
            "$GPU_ENV4" \
            STARLING_APP_RUN="$SELF" \
            "$@"
    else
        # Already the login user — and this is the SHIPPED path: GDM starts
        # the session as the user, so every app the launcher spawns comes
        # through here. Keep the caller's env but scrub the Starling-Mesa
        # vars, and GNOME_DESKTOP_SESSION_ID.
        #
        # That last one is not cosmetic. GDM exports it (literal value
        # "this-is-deprecated") and the shell inherits it, so without the
        # scrub every Chromium app SEGFAULTS on launch: base/nix/xdg_util.cc
        # treats the variable as proof of a GNOME session regardless of our
        # XDG_CURRENT_DESKTOP=Starling, and the GNOME-only path it then takes
        # dies here. Chrome and VS Code both, on a stock install.
        #
        # It survived this long because every way we tested Chrome missed it:
        # the root branch above starts from `env -i`, so `sudo app-run chrome`
        # is clean, and a developer's ssh session has no GNOME_DESKTOP_
        # SESSION_ID either. Only a real GDM login sets it — the one path
        # nobody launches a browser from by hand.
        #
        # AUDIO, and it has to be here as well as in the root branch: we
        # override XDG_RUNTIME_DIR to our private $XDG_DIR, and libpulse
        # looks for the server at $XDG_RUNTIME_DIR/pulse/native — which does
        # not exist there. The real socket is PipeWire's, under the login
        # user's /run/user/UID. Without PULSE_SERVER an app finds no Pulse
        # server at all and silently falls back to raw ALSA (Zoom was sitting
        # on /dev/snd/controlC1) or to no audio, on the SHIPPED path only —
        # `sudo app-run` looked fine, because the root branch sets this.
        PULSE_SOCK="/run/user/$(id -u)/pulse/native"
        [ -S "$PULSE_SOCK" ] && PULSE_ENV="PULSE_SERVER=unix:$PULSE_SOCK" || PULSE_ENV="PULSE_UNSET="
        exec env \
            -u LD_LIBRARY_PATH -u MESA_LOADER_DRIVER_OVERRIDE \
            -u VK_ICD_FILENAMES -u GBM_BACKENDS_PATH \
            -u GNOME_DESKTOP_SESSION_ID \
            PATH="$APPBIN:$PATH" \
            XDG_RUNTIME_DIR="$XDG_DIR" \
            "$PULSE_ENV" \
            "$GPU_ENV1" "$GPU_ENV2" "$GPU_ENV3" \
            WAYLAND_DISPLAY="$SOCKET" \
            DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" \
            DISPLAY="${DISPLAY:-:1}" \
            "$GPU_ENV4" \
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

# PRIME offload inside the sandbox: same translation as the host-direct
# branches, as --setenv prepended to "$@" (options-before-command, the same
# shape as the --ro-bind loops above).
if [ "${STARLING_APP_GPU:-}" = "discrete" ]; then
    set -- --setenv STARLING_APP_GPU discrete \
           --setenv MESA_LOADER_DRIVER_OVERRIDE zink \
           --setenv DRI_PRIME 1 \
           "$@"
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
