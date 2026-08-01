# Building Starling from scratch

Everything needed to go from an empty machine to a running desktop, in order.
Both halves get built: **starling-engine** (the Flutter engine fork, C++) and
**starling-desktop** (the Swift framework port, shell, and apps).

Verified end to end on **2026-07-25** on a fresh **Ubuntu 26.04 LTS (resolute)**
— 12 vCPU, 16 GB RAM, 200 GB disk — starting from a plain cloud image with no
toolchain of any kind installed, and finishing with the desktop running on DRM
and an app window compositing.

| step | wall clock | disk |
|---|---|---|
| `gclient sync` (engine DEPS) | 25 min | 29 GB |
| engine `ninja` host_debug | 8 min | 680 MB |
| engine `ninja` host_release | 7 min | 308 MB |
| desktop `swift build` — shell | 2 min | |
| desktop `swift build` — 5 apps | 9 min (1m45 each) | |
| `build/stage.sh` | seconds | 252 MB |
| `build/package-desktop.sh` | ~1 min | 61 MB `.deb` |
| **total** | **~55 min** | **~41 GB** |

Budget **60 GB of free disk**. **Ubuntu 26.04 LTS is the base platform**, for
test and for production. It comes with two toolchain-vs-distro mismatches, both
handled in-tree — `./bootstrap.sh` and the package manifests — so there is
nothing extra to type. What they are and why is in
[26.04 notes](#ubuntu-2604-notes).

---

## 0. Prerequisites

- x86_64 **Ubuntu 26.04 LTS** — the base platform, and the only release these
  instructions target.
- Both repositories are public, so cloning needs no credentials. If you plan
  to push, register an SSH key with your account:

  ```bash
  ssh -T git@github.com     # must greet you by name, not ask for a password
  ```

- **Pick the final path of the engine checkout before you build.** ninja keys
  its cache on the absolute paths in compile command lines, `out/*/args.gn`
  records an absolute `default_git_folder`, and every Swift binary gets an
  absolute rpath into the engine's `out/host_debug`. Moving the checkout later
  means re-running `gn gen`, a full ~4400-step rebuild per config, and
  relinking every Swift binary.

The three repos sit side by side, which is what `bootstrap.sh` expects:

```
~/dev/starling-build/
    starling-engine/     the C++ half (also the flutter monorepo root)
    flutter-swift/       the Flutter→Swift framework port (SwiftPM "FlutterSwift")
    starling/            the desktop — shell, compositor, apps, packaging
```

`bootstrap.sh` makes `starling/engine` and `starling/sdk` symlinks into the
first two, so every manifest in the desktop can say `../engine` and `../../sdk`
without hardcoding where you cloned things.

---

## 1. The engine

### 1.1 Host packages

```bash
sudo apt-get update
sudo apt-get install -y git curl unzip python3 pkg-config
```

That is all the engine build takes from the distro. clang, the Dart SDK, ninja,
and even a Debian sysroot for the system libraries the DRM embedder links
against (`libdrm`, `gbm`, `EGL`, `GLESv2`, `input`, `udev`, `xkbcommon`) are
hermetic — `gclient` fetches them into the checkout. No `-dev` packages needed
for this half.

### 1.2 depot_tools

```bash
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ~/depot_tools
export PATH="$HOME/depot_tools:$PATH"       # put this in your shell profile
```

`gclient`, `ninja`, and `vpython3` all come from here. `flutter/tools/gn` has a
`#!/usr/bin/env vpython3` shebang, so without depot_tools on PATH it fails with
`env: 'vpython3': No such file or directory`.

### 1.3 Clone, and write the gclient solution

`starling-engine` is a fork of `flutter/flutter`, so it carries upstream's full
history — a clone is ~600 MB and takes a few minutes. Starling's work is the
`starling` branch, which is the repo default:

```bash
mkdir -p ~/dev/starling-build && cd ~/dev/starling-build
git clone https://github.com/starling-build/starling-engine.git
cd starling-engine
git remote add upstream https://github.com/flutter/flutter.git   # for rebases
```

Add `--branch starling --single-branch` to the clone if you want to skip
upstream's other branches. **Pick the final path before building** — see the
warning above; ninja and every Swift rpath bake in absolute paths.

`gclient` needs a `.gclient` at the repo root. It is per-checkout state and
deliberately untracked, so derive it from the upstream template in the tree:

```bash
sed 's#https://github.com/flutter/flutter.git#https://github.com/starling-build/starling-engine.git#' \
    engine/scripts/standard.gclient > .gclient
```

The solution is `"managed": False`, so `gclient` never touches the root
repository's checkout — it only hydrates `DEPS`.

### 1.4 Hydrate DEPS

```bash
gclient sync -D
```

25 minutes and 29 GB: ~50 third-party repositories, a prebuilt Dart SDK, the
clang toolchain, the sysroots. Transient
`WARNING: subprocess ... failed; will retry after a short nap` lines are normal
— gclient retries and the sync still succeeds. On a slow link,
`gclient sync --no-history` shallows the sub-repos.

### 1.5 Generate the build files

```bash
cd engine/src
flutter/tools/gn --runtime-mode=debug   --no-lto --no-backtrace --no-rbe
flutter/tools/gn --runtime-mode=release --no-lto --no-backtrace --no-rbe
```

This writes `out/host_debug/args.gn` / `out/host_release/args.gn` and runs
`gn gen`. **`out/` is untracked, so a fresh clone has no `args.gn` — these two
commands are what create it.** (`gn` itself lives at
`flutter/third_party/gn/gn`, not in `buildtools/`, which only carries clang.)

### 1.6 Build the two libraries

```bash
ninja -C out/host_debug   libflutter_engine.so libflutter_linux_drm.so
ninja -C out/host_release libflutter_engine.so libflutter_linux_drm.so
```

**depot_tools must be on PATH for these too**, not just for `tools/gn` (§1.2).
GN actions shell out to `vpython3` — SPIRV-Tools' table generator is the first
— so a build launched from a shell without it dies ~90 steps in with
`/bin/sh: 1: vpython3: not found`. Editors, CI, and `nohup`/background shells
that skip your profile are the usual way this bites.

~4400 steps per config. **Build both:**

- `host_debug` is what every Swift package links against and bakes into its
  rpath (`engineOutDir` in each `Package.swift`), so the desktop will not link
  without it — even for a release desktop build.
- `host_release` is what `stage.sh` copies into the shipping tree, and what
  packaging requires.

Each config yields `libflutter_engine.so`, `libflutter_linux_drm.so`, and
`icudtl.dat`. That is the entire interface the desktop consumes. Later
engine-only changes rebuild in seconds and need **no Swift relink**: the shell
binds only the engine's stable C API.

The engine's public headers are **vendored** into `sdk/`, not read out of the
checkout, so `sdk/` compiles with no engine tree present and needs the engine
only at link time. `sdk/tools/sync-vendored-headers.sh` refreshes them and
`--check` reports drift; re-run it after changing a bridge header in the engine.

---

## 2. The desktop

### 2.1 Host packages

```bash
sudo apt-get install -y \
    build-essential binutils libc6-dev libcurl4-openssl-dev libedit2 \
    libncurses-dev libpython3-dev libsqlite3-0 libxml2-dev libz3-dev \
    pkg-config tzdata unzip zlib1g-dev
sudo apt-get install -y \
    libwayland-dev libxkbcommon-dev libdrm-dev libgbm-dev libegl-dev \
    libgles-dev libinput-dev libudev-dev libsystemd-dev libxshmfence-dev \
    libx11-dev libxcb1-dev libpixman-1-dev
```

First group: Swift's own prerequisites. Second: what the shell's C targets
compile and link against — the Wayland compositor (`wayland-server`,
`xkbcommon`), the DRM/GBM/EGL stack, `libinput`/`libudev`, sd-bus for the portal
(`libsystemd`), and the in-tree X server's `xshmfence`.

### 2.2 Swift 6.2.4, at exactly the right path

Every `Package.swift` hardcodes the toolchain include directory:

```swift
let swiftToolchainInclude = NSHomeDirectory() + "/.local/share/swiftly/toolchains/6.2.4/usr/include"
```

so the toolchain **must** live at `~/.local/share/swiftly/toolchains/6.2.4/`.
swift.org publishes no `ubuntu26.04` build of 6.2.4; the `ubuntu24.04` one runs
fine on 26.04:

```bash
TC="$HOME/.local/share/swiftly/toolchains/6.2.4"
mkdir -p "$TC"
curl -fL -o /tmp/swift.tar.gz \
  https://download.swift.org/swift-6.2.4-release/ubuntu2404/swift-6.2.4-RELEASE/swift-6.2.4-RELEASE-ubuntu24.04.tar.gz
tar -xzf /tmp/swift.tar.gz -C "$TC" --strip-components=1
export PATH="$TC/usr/bin:$PATH"
swift --version          # Swift version 6.2.4 (swift-6.2.4-RELEASE)
```

Installing 6.2.4 with `swiftly` itself produces the same layout and is equally
fine — the path is what matters, not how the toolchain got there.

On 26.04, `swift-build` cannot start until the toolchain gets a libxml2 compat
symlink; `./bootstrap.sh` in the next step creates it.

### 2.3 Clone, and point it at the engine and the framework

The Flutter→Swift framework is its own repo. Clone it beside this one:

```bash
cd ~/dev/starling-build
git clone https://github.com/starling-build/starling-sdk.git
git clone https://github.com/starling-build/starling.git
cd starling
./bootstrap.sh                  # engine -> ../starling-engine/engine
                                # sdk    -> ../starling-sdk
```

Every engine and framework reference in this repo goes through those two
symlinks; pass paths to `bootstrap.sh` to use checkouts elsewhere
(`./bootstrap.sh <engine> <starling-sdk>`, or `$STARLING_ENGINE` /
`$STARLING_SDK`).

### 2.4 Build the shell and the apps

```bash
swift build -c release --package-path shell
for a in SettingsApp FileExplorerApp TerminalApp CalculatorApp AppStoreApp; do
    swift build -c release --package-path "apps/$a"
done
```

No extra flags on any release: the manifests carry what 26.04 needs.

The shell pulls in `sdk/` (the `FlutterSwift` framework port) as a package
dependency, so there is nothing to build there separately. Those five apps are
the set the `.deb` ships; `apps/` holds more, and any app with a built binary
gets picked up by staging — so build only what you want shipped.

### 2.5 Stage

```bash
build/stage.sh                  # -> .stage/
```

`stage.sh` is the single definition of the installed layout: the shell, the
engine libraries, the Swift runtime, the apps, and the assets, collected into
one self-contained tree that mirrors what the package installs.

**Always run from the staged tree, never straight out of `.build`.** Child apps
are spawned with `LD_LIBRARY_PATH` scrubbed and resolve libraries through their
own `$ORIGIN` only, so they work solely when the libraries sit beside them —
exactly what staging arranges. A `.build`-relative layout appears to work right
until a child app dies with
`libflutter_engine.so: cannot open shared object file`.

---

## 3. Run it

```bash
build/run-desktop.sh
```

Re-stages, then runs the desktop out of `.stage/`. It needs the GPU free — no
display manager or compositor holding `/dev/dri/card*`:

```bash
sudo systemctl isolate multi-user.target     # or drop to a TTY
sudo fuser -v /dev/dri/card*                 # expect nothing
```

Seat access is automatic: libseat (seatd or logind, no sudo — the shipping
model) when a seat manager is reachable, else a root device open via sudo.

Drive it and take screenshots without touching a keyboard:

```bash
sudo build/shell-drive.py "click 1125 1035" "shot /tmp/x.png"
```

Note the quoting: each action **and its arguments** is one argv entry.

---

## 4. Package

```bash
build/package-desktop.sh        # -> starling-desktop_<ver>_amd64.deb
```

Wraps `stage.sh`'s output with control metadata, the polkit policy, and the
session entry, and computes `Depends` with `dpkg-shlibdeps`. Prereqs: the
release shell, the five apps, and the engine's **`host_release`**.

The result
bundles the Swift runtime and the engine privately, installs under
`/usr/lib/starling` + `/usr/share/starling`, and adds a "Starling" session to
the login screen. It `Recommends: gdm3 | lightdm | sddm` — a bare server image
has no display manager, and without one nothing shows the session menu.

---

## Ubuntu 26.04 notes

Two things break on 26.04 and on no earlier release. Both come from running an
`ubuntu24.04`-built Swift toolchain on a newer distro — neither is a Starling
bug, and both are now fixed in-tree, so this section is background rather than
instructions. **Both disappear once swift.org ships a 26.04 release toolchain**
(`main` snapshots have had one since 2026-07-11); at that point delete the fixes.

### `libxml2.so.2: cannot open shared object file`

26.04 ships only `libxml2.so.16` (package `libxml2-16`); the toolchain's
`libFoundationXML.so` links the old soname, so `swift-build` won't even start.
Its `RUNPATH` is `$ORIGIN`, so a symlink beside it is enough — nothing
system-wide changes.

**Fixed by `bootstrap.sh`**, which creates that symlink when the distro has no
`libxml2.so.2` of its own. Idempotent, and a no-op on older releases.

### `cmath:100: redefinition of 'acos'` → `could not build C module '_FoundationCShims'`

Every Starling target uses C++ interop, so the clang importer compiles
Foundation's C shim in **C++** mode. Its `#include <math.h>` then resolves to
libstdc++'s C++ wrapper, which pulls `<cmath>` in textually — while the prebuilt
`std` module already contains it. clang sees every overload twice. 26.04's
glibc 2.43 / libstdc++ 15 combination is what exposes it; 25.10 (glibc 2.42)
builds clean. It is not a Swift-version problem — 6.3 fails identically.

The fix predefines the wrapper's include guard so it stops pulling `<cmath>`,
and force-includes glibc's `math.h` so every TU still gets the C declarations —
what libstdc++'s own `_GLIBCXX_INCLUDE_NEXT_C_HEADERS` path would do:

```bash
-Xcc -D_GLIBCXX_MATH_H -Xcc -include -Xcc /usr/include/math.h
```

**Carried by every `Package.swift`** as `glibcMathCompat`, folded into the
`toolchainSwiftCFlags` each Swift target already passes to the clang importer.
Applied on all Linux releases rather than version-gated: the semantics are
identical on older glibc, and uniform behaviour is the point of a base platform.
Putting it in the manifests rather than a wrapper script also keeps
sourcekit-lsp working — the editor hits the same failure otherwise.

Verified against all three consumers: the Swift importer (Foundation *and* the
C++ `std` module), C++ TUs including `<cmath>`, and C++ TUs including
`<math.h>`.

One caveat worth knowing: `#include <math.h>` in C++ no longer injects the
`using std::…` names into the global namespace. Nothing in the tree relies on
that.

### Watch out when testing workarounds

clang's module cache makes flag experiments lie: a `.pcm` built under one flag
set gets reused under another, so a broken configuration can appear to pass.
Clear it between attempts:

```bash
rm -rf ~/.cache/clang
```

---

## Traps

- **depot_tools must be on PATH** for `gn`/`gclient`/`ninja`, including for
  `flutter/tools/gn`'s `vpython3` shebang.
- **`out/*/args.gn` is not in the repo** — a fresh clone must run
  `flutter/tools/gn` before `ninja`.
- **Build both engine configs.** A `host_debug`-only build cannot be packaged;
  a `host_release`-only build cannot be linked against.
- **The Swift toolchain path is hardcoded** to
  `~/.local/share/swiftly/toolchains/6.2.4`.
- **Never forward the engine's env knobs as empty strings.** They are read with
  a bare `getenv()`, and `""` is non-NULL in C: `FLUTTER_DRM_CONNECTOR=""` makes
  the connector filter reject every output, giving
  `[DRM] No connected connector found` on a perfectly good display. Forward
  optional vars only when non-empty (see `build/run-desktop.sh`).
- **If the shell dies uncleanly** it leaves `/tmp/xdg-starling/wayland-0.lock`
  and the next run listens on `wayland-1`; clients must use the socket from the
  current run's `wayland_server: listening on wayland-N` log line.
- `pkill -f <word>` matches its own `bash -c` line — use `pkill -x`.
