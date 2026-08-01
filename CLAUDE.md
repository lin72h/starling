# starling-desktop — project guide

The Starling desktop: Swift shell + compositor + apps, running on the Flutter
engine's C core from the sibling repo **starling-engine** and the Flutter→Swift
framework from the sibling repo **flutter-swift**. Both are reached through
repo-root symlinks (`engine`, `sdk`) that `./bootstrap.sh` makes after cloning.
Read starling-engine's `CLAUDE.md` too: a feature usually touches more than one
of these repos, and they all get committed.

Everything needed to build, run, drive, and package the desktop is in this repo
(`build/`). The older `starling-os` repo still holds the Bazel-built Starling OS
image and its QEMU boot gates; the desktop dev loop no longer depends on it.

## Layout

```
sdk         -> SYMLINK to a flutter-swift checkout (SwiftPM package
               "FlutterSwift"): the Flutter→Swift framework port, no Dart VM.
               Its own repo — edit and commit it there, not here.
engine      -> SYMLINK to a starling-engine checkout
host/       the windowed host (FlutterRunner + GLFWBridge): run a Swift Flutter
            app in an ordinary window instead of compositing through the shell.
            Demos only — BlueScreenApp and Examples/HelloWindow. Stayed behind
            when the framework was extracted, because it drags a vendored libglfw
            and resolves assets under /usr/share/starling.
registry/  the app registry — the ONE description of every app the desktop knows
           about (catalog.d/*.app), shared by the shell and the App Store
shell/     DesktopShellApp package — its own CLAUDE.md in Sources/DesktopShellApp/
  Sources/DesktopShellApp/   Shell/ Window/ Compositor/ Wayland/ Taskbar/ Launcher/ Portal/ Utils/
  Sources/WaylandServer/     the Wayland compositor, in C (~5k lines)
  Sources/PortalService/     xdg-desktop-portal (sd-bus/basu)
  Sources/X11Server/         in-tree X server (DRI3/Present) — do not touch unless asked
apps/      first-party apps, one SwiftPM package each
build/     stage.sh (assembles the tree — the single definition of the layout),
           run-desktop.sh (run it), shell-drive.py (input + screenshots),
           package-desktop.sh (Ubuntu .deb), app-run/app-install,
           tools/ (drm_screenshot), vendored flutter_assets, bundled wallpapers
           live in shell/Resources
macos-compat/  research: running unmodified Mach-O macOS binaries on Linux.
               Not part of the desktop, and deliberately not part of the SDK.
docs/plans/    design notes, including standalone-sdk.md — why the framework is
               its own repo and how it is distributed
```

## Build & iterate

- Shell/app Swift change → `cd shell && swift build -c release` (apps likewise),
  then `build/run-desktop.sh` (it re-stages first).
- Engine C++ change → rebuild in the **engine repo** (`ninja -C engine/src/out/host_debug
  libflutter_linux_drm.so libflutter_engine.so`) — no shell relink needed.
  Rebuild host_release too before packaging.
- Run: `build/run-desktop.sh` — stages into `.stage/` then runs from there.
  Drive/screenshot with `sudo build/shell-drive.py …`.
- Package: `build/package-desktop.sh` → .deb. It consumes `build/stage.sh`, which
  is the **single definition of the layout** — change assembly there, never in
  the packager alone.
- Test: `test/run.sh` (~0.4s, no GPU — run it on every change),
  `test/run.sh --build` to compile everything and the .deb,
  `sudo test/run.sh --functional` to drive a live desktop, and `test/vm.sh`
  for the release gate (.deb on a clean VM through a real GDM login — the only
  tier that can see privilege-path bugs). See `test/README.md`.
- Building on a machine with **nothing installed** (both repos, toolchains,
  apt packages, `gclient`) → `docs/BUILDING.md`.

**Ubuntu 26.04 LTS is the base platform**, for dev, test, and the shipped .deb.
The 6.2.4 toolchain is an ubuntu24.04 build, so 26.04 needs two fixes — both
already in-tree, so `swift build` takes no special flags: `bootstrap.sh` adds
the toolchain's `libxml2.so.2` symlink, and every `Package.swift` carries
`glibcMathCompat` (`-D_GLIBCXX_MATH_H` + a force-included glibc `math.h`) for
glibc 2.43's `<cmath>` clash. Delete both when swift.org ships a 26.04
toolchain. Why, in full: `docs/BUILDING.md`.

**Always run from the staged tree, never straight out of `.build`.** Child apps
are spawned with `LD_LIBRARY_PATH` scrubbed (`STARLING_CHILD_HOST_GL`) and
resolve libraries through their own `$ORIGIN`/RUNPATH only, so they work solely
when the libraries sit beside them — exactly what staging (and the package)
arranges. A `.build`-relative layout appears to work right up until a child app
dies with `libflutter_engine.so: cannot open shared object file`.

## Apps are data, not code

Adding an app is **one file**: `registry/catalog.d/<id>.app` (plus a launch
recipe in `build/app-run.sh` and an install recipe in `build/app-install.sh`
if it is a third-party host app). Never add an app id to a table in the shell
or the store — there are no such tables any more, and reintroducing one is how
this drifted the first time: an app was in seven tables and missing from two,
so it launched but had no dock icon and no real icon.

- `registry/catalog.d/*.app` — shipped, read-only. Name, tile colour, glyph,
  dock position, store copy, install/launch recipe names, the `.desktop`
  entries to read, the window classes its windows report. Read by the shell's
  launcher and dock, the App Store, and `app-install`.
- `/var/lib/starling/installed.d/<id>.app` — written by `app-install` on a
  successful install, deleted on removal. Carries what only exists once the
  app is on disk: its `.desktop` file, `StartupWMClass`, icon, version. The
  shell watches this directory (inotify), so an install lights up the launcher
  and dock with no relogin.
- Debug it with `app-install --record <id>`, which re-resolves and rewrites one
  record without installing anything (`STARLING_APP_RECORDS=<dir>` to test
  unprivileged), then `cat` the result.

**Window → app identity is `app_id`, never the title.** A window's
`xdg_toplevel.set_app_id` matches the `StartupWMClass` in the app's `.desktop`
entry; that pairing exists for exactly this purpose and `app-install` records
it. Title matching cannot work in general — IntelliJ's project window is
titled `untitled – Main.java`, with nothing app-shaped in it — so it is opt-in
per record (`TitleMatch=`) and only for windows that carry no app_id at all:
Zoom on the in-tree X server, WeChat inside rootful Xwayland, and Waydroid,
which renders every Android app into one window.

## Standing directions

- **Wayland only.** Do not read, modify, or reference `X11Server/` or X11 launch
  paths unless explicitly asked.
- **No security hardening on the app runtime** (`build/app-run.sh` is an app
  environment, not a sandbox; its bwrap flags are load-bearing for the runtime).
- **Never post code or file contents to external paste services.**

## Traps that have cost real time

Framework (`sdk/`):
- `ColoredBox` hit-tests **opaque even at alpha 0** — use a bare
  `SizedBox(expand:)` with `Listener(behavior: .translucent)` for overlays.
- Registering `onDoubleTap` kills **both** tap and double-tap on the DRM
  embedder (`Foundation.Timer` never fires there). Detect double-clicks
  manually inside `onTap`; use `DispatchQueue.main.asyncAfter` + a generation
  token for any timer.
- A widget tree with no `FluentApp`/`MacosApp` above it **must** be wrapped in
  `Directionality`.
- Lazy sliver list children don't rebuild on ancestor rebuild — theme/state
  changes need a bloc `.refresh` poke.
- Element **remount is the dominant update path** (no `updateRenderObject`); if
  fresh content never composites, suspect paint marking.
- `print()` is block-buffered through pipes — debug with raw `write(2, …)`.
- Widgets have **two spellings**: the ported `children:`/`child:` initializers
  (canonical, 1:1 with Dart) and the trailing-closure overloads in
  `Widgets/ResultBuilders.swift`, which add `if`/`for`/`switch` inside the tree.
  They compile to the identical tree. **Adding a parameter to a ported widget
  init means adding it to that widget's builder overload too** — otherwise the
  block form silently cannot express it, with no warning at the call site.
  `test/lint.py` compares the two and fails on drift.

Build / runtime:
- **Clang normalises `-L` paths lexically, and `sdk` is a symlink out of the
  tree.** `sdk` points at a flutter-swift checkout beside this repo, so a path
  built as `<repo>/sdk/../<something>` is correct on disk — the kernel resolves
  the symlink first, so it lands beside *flutter-swift*, not beside the repo.
  Clang collapses `sdk/..` textually and looks beside the repo instead. The
  build then fails with `cannot find -lflutter_engine` against a `-L` you can
  read on the command line and confirm by hand: `ls` finds the library, and
  `ld` with the same `-L` links fine, because ld does no such rewrite. Only
  `clang -###` reveals the substitution. Anything that composes a path through
  `sdk/..` or `engine/..` must canonicalise it — `resolvingSymlinksInPath()`,
  never `.standardized`, which does exactly the collapse clang does.
- **Never forward the engine's env knobs as empty strings.** Several are read
  with a bare `getenv()`, and `""` is non-NULL in C: `FLUTTER_DRM_CONNECTOR=""`
  makes the connector filter compare every output against `""` and reject them
  all — `[DRM] No connected connector found` on a perfectly good display.
  Forward optional vars only when non-empty (see `build/run-desktop.sh`).
- App RUNPATHs must be **absolute** (`appPackageDir` in each `Package.swift`,
  mirroring `sdk/`). They used to be cwd-relative and worked only because the
  shell's cwd happened to be `apps/DesktopShellApp`.
- **Dev mode runs third-party clients as ROOT; a real session does not.** The
  shell under `run-desktop.sh` owns the Wayland socket as root, so clients have
  to be root too — but GDM starts apps as the user, so anything you conclude
  about a third-party app from the dev box may be an artifact. Three "bugs"
  chased this way turned out to be exactly that: Teams died on
  `FATAL: The SUID sandbox helper binary ... is not configured correctly`
  (Chromium refuses the setuid path as root), Spotify started seven processes
  and never drew a window (dconf could not write in the root-owned
  `XDG_RUNTIME_DIR`), and Teams' earlier `SIGILL` did not reproduce at all.
  **Test user-facing app behaviour in the VM** (`starling-vm/`, apps run as
  `tester` through a real GDM login); use the dev box for GPU-specific
  questions — that is what confirmed the GTK4 crash is not a virgl artifact.
- **Root mode also HIDES bugs, not just invents them** — and those are worse,
  because the dev box says the feature works. `main.swift` pinned the portal's
  bus address only under `getuid() == 0`; unprivileged it passed nil, so sd-bus
  honoured the inherited `DBUS_SESSION_BUS_ADDRESS` and the portal claimed
  `org.freedesktop.portal.Desktop` on the user's real `/run/user/<uid>/bus`
  instead of the session's `$XDG_RUNTIME_DIR/bus` that `app-run` points every
  client at. The name was then unowned on the session bus, so the first client
  request D-Bus-activated the stock `xdg-desktop-portal` there, which has no
  `Starling` backend and therefore no FileChooser — every file dialog in every
  Chromium/Electron/GTK app broke. It worked perfectly under `sudo`. **When a
  shipping path differs from the dev path by a privilege check, test the
  unprivileged one**: `LIBSEAT_BACKEND=seatd /usr/libexec/starling-session`
  runs the real packaged session unprivileged over SSH, given `seatd` is
  active and you are in the `video` group.
- **A session-bus name is not yours just because you claimed it.** The private
  dbus-daemon still searches `/usr/share/dbus-1/services`, so system services
  are activatable on it, and we ask for our name with `ALLOW_REPLACEMENT`.
  Mask anything that would compete by dropping a stub `.service` in the
  private `XDG_DATA_HOME` servicedir (searched first) — that is what both
  launchers do for `org.freedesktop.secrets` and
  `org.freedesktop.portal.Desktop`. To check who actually answers:
  `busctl --address=unix:path=/tmp/xdg-starling-$(id -u)/bus call
  org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus
  GetNameOwner s <name>` (the runtime dir is per-user — use the uid of
  whoever runs the session).
- **A plain `swift build` can silently give you a stale `sdk/`.** Each package
  compiles its own copy of the framework, and their incremental state does not
  always notice that `sdk/` moved underneath them. Adding a *new file* there is
  the worst case: dependents fail with `cannot find <symbol> in scope` even
  though the manifest lists it. Editing an existing file is more dangerous,
  because it fails silently — you get a binary built from the old code and no
  error at all. This has already invalidated one round of testing and produced
  a confidently wrong conclusion about where a bug was. When a change to `sdk/`
  appears to have no effect, before theorising:

      rm -f  <pkg>/.build/release.yaml <pkg>/.build/build.db
      rm -rf <pkg>/.build/*/release/Flutter.build
      swift build -c release        # twice: the first re-plans

Engine / compositor:
- **Audit `wayland_server_on_*` in the header against what
  `WaylandIntegration.swift` actually registers.** This has now bitten twice.
  `on_shm_surface_commit` was unregistered and every software client
  composited as nothing (1b1050a); `on_app_id_changed` was unregistered, so
  every window's app_id was thrown away and the dock guessed from titles —
  which meant no dock icon for IntelliJ or GIMP, and could not have worked for
  IntelliJ at all. In both cases the C side was complete: declared, defined,
  called. Nothing warns you.
- **A C callback the Swift side never registers fails silently and looks like
  a rendering bug.** `wayland_server_on_shm_surface_commit` was declared,
  defined, and called by `wayland_compositor.c` — but nothing in
  `WaylandIntegration.swift` ever set it, so the SHM branch tested
  `server->cb.on_shm_surface_commit &&` against NULL and dropped every
  software frame. The protocol side looked perfect from the client's seat:
  buffers attached, damaged, committed, and *released*, so a `WAYLAND_DEBUG`
  trace showed nothing wrong — the window just composited as nothing. Every
  `wl_shm` client was affected (IntelliJ, `weston-simple-shm`), while dma-buf
  clients were fine, which reads as "that one app is broken" rather than "half
  the compositor is unwired". When one class of client renders and another
  doesn't, check the callback is actually **set** before reading the paths it
  feeds. Two format traps live in that handler: `wl_shm`'s ARGB/XRGB8888 is
  B,G,R,A in memory but the CPU texture path uploads `GL_RGBA`, and toplevels
  routinely commit alpha=0, which composites the window away unless alpha is
  forced opaque (dma-buf sidesteps this by importing an opaque fourcc; the X
  server's shadow blit forces `0xff` for the same reason).
- **Java/Swing needs two X server gaps closed, and one of them crashes the
  client, not the server.** XI1 `ListInputDevices` must reply — AWT blocks on
  it during init holding the toolkit lock, so treating it as void deadlocks
  the app before it maps a window. And RENDER `QueryPictFormats` must list the
  depth-32 root visual: `XRenderFindVisualFormat` returns NULL for a visual we
  omit and `XRenderCreatePicture` then segfaults *inside libXrender*, with no
  protocol error to show for it. Even with both fixed, our RENDER is a drawing
  stub (`CreatePicture` is a no-op), so Java2D needs
  `-Dsun.java2d.xrender=false` to reach the paths we implement.
- `EvdevToHID` (engine repo, `fl_drm_input.cc`) and
  `WaylandIntegration.hidToEvdev` (shell) are exact inverses. **Change one,
  change the other**, or letters break for Wayland clients.
- If the shell dies uncleanly it leaves `/tmp/xdg-starling-<uid>/wayland-0.lock`
  and the next run listens on **wayland-1**; clients must use the socket from
  the current run's `wayland_server: listening on wayland-N` log line.
- `pkill -f <word>` matches its own `bash -c` line — use `pkill -x`.
