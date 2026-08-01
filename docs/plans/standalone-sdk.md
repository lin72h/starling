# Splitting `sdk/` into a standalone package

> **Status 2026-08-01: reversed.** The framework moved back into this repo
> at `sdk/` (git subtree, full history) so one public repo carries the whole
> desktop — a single front door beats two half-trafficked ones for now. The
> packaging work below still holds; `git subtree split --prefix=sdk`
> re-extracts the folder, history intact, if a standalone package becomes
> worth it again.

Goal: `FlutterSwift` becomes a Swift package someone else can depend on, on Linux
and macOS, without checking out starling-desktop or the engine.

The framework code is already almost free of the desktop. A grep for
`starling|DesktopShell` across 190k lines of `Sources/` finds six hits, and only
one is real coupling: `Platform/AgentSemanticsEndpoint.swift` reads
`$STARLING_AGENT_ENDPOINT`. **The coupling is in the build, not the code.** So
this is a packaging job, not a rewrite.

## Done

**Compile-time engine dependency removed.** The package used to reach into the
engine checkout from three places — the modulemap's 33 headers, plus
`FlutterEmbedderBridge.h` and `FlutterDRMBridge.h`, all by
`../../../../engine/src/...` relative path. Those 35 headers turn out to be a
closed set (181 KB + 180 KB; the bridge headers cross-reference by bare filename,
`embedder.h` and `fl_drm_view.h` include only libc), so they are now vendored
under each target's `include/engine/` by `tools/sync-vendored-headers.sh`.

`swift_runtime_controller.h` is deliberately *not* vendored — it pulls
`runtime_controller_interface.h` and from there FML, tonic and `dart_api.h`. It
was never in the modulemap and the framework does not need it.

Verified: the whole package, `libFlutterShared.so` included, builds from a
directory with no engine tree anywhere, given only
`FLUTTER_SWIFT_ENGINE_OUT=<a built engine>`. `engineOutDir` and
`swiftToolchainInclude` also became env-overridable, since neither is a property
of the package.

The engine is now a **link-time dependency only**.

**The toolchain include flag is gone too** — the big one, because it sat on every
Swift target and so tainted every product. Its entire purpose turned out to be
one header: the bridge headers `#include <swift/bridging>`, and clang cannot find
it without an absolute `-I` into the Swift installation. Removing the flag fails
with exactly that, and nothing else:

```
error: 'swift/bridging' file not found
error: could not build C module 'FlutterSwiftBridgeCxx'
```

All the headers take from it is `SWIFT_SHARED_REFERENCE` (81 uses) and
`SWIFT_RETURNS_INDEPENDENT_VALUE` (13). Those are what hand the C++ objects to
Swift ARC, so an `__has_include` fallback with no-op macros would compile and then
corrupt memory — the real definitions must be present. So `swift/bridging` (11 KB)
is vendored into `FlutterSwiftBridgeCxx/include/swift/`, where it resolves through
the target's own include path. Verified building with no toolchain flag at all.

The tradeoff to keep in view: our copy shadows the toolchain's for anyone on a
different Swift version. `--check` compares against the toolchain in use, so
drift is visible, but an incompatible future `bridging` breaks here.

## The actual blocker: `unsafeFlags`

A package using `.unsafeFlags` cannot be consumed by another package through a
version requirement. Confirmed empirically — tag the package, depend on it by
URL + version, and SwiftPM refuses before compiling anything:

```
error: the target 'Flutter' in product 'Flutter' contains unsafe build flags
error: the target 'DmaBufBridge' in product 'Flutter' contains unsafe build flags
error: the target 'SwiftRuntime' in product 'Flutter' contains unsafe build flags
error: the target 'FlutterSwiftBridge' in product 'Flutter' contains unsafe build flags
error: the target 'FlutterSwiftBridgeCxx' in product 'Flutter' contains unsafe build flags
```

So moving files to a new repo achieves nothing on its own: the package would be
unusable as a dependency the moment it arrived. **Eliminating `unsafeFlags` is
the split.** Everything below is that work, easiest first.

| Flag | Target(s) | Resolution |
|---|---|---|
| ~~`-lgbm -lEGL -lGLESv2`~~ | ~~DmaBufBridge~~ | **done** — `.linkedLibrary("gbm")` etc. |
| ~~`-I/usr/include/libdrm`~~ | ~~DmaBufBridge~~ | **done** — the flag was *dead*. The target includes only `<gbm.h>`, EGL, GLES2 and libc; preprocessing it reaches no libdrm header at all. Deleted, no pkg-config needed |
| ~~`-strict-concurrency=minimal`~~ | ~~Flutter~~ | **done** — `.swiftLanguageMode(.v5)`, which is safe. Not a pure concurrency knob though: mode 5 also disables bare regex literals, and `Foundation/Print.swift` has one, so it needs `.enableUpcomingFeature("BareSlashRegexLiterals")` alongside — also safe |
| `-l<engineLinkName>` | FlutterSwiftBridge, tests | `.linkedLibrary(...)` — safe |
| `-L<engineOutDir>`, `-rpath` | FlutterSwiftBridge, tests | **the only genuinely open one.** No safe equivalent. Needs the engine discoverable as a system library — a `.pc` file and a `.systemLibrary` target — or the consumer setting rpath themselves |
| ~~`-Xcc -I<toolchain>/usr/include`, `-isystem` same~~ | ~~every Swift target~~ | **done** — `<swift/bridging>` vendored instead |
| `-D_GLIBCXX_MATH_H`, `-include /usr/include/math.h` | every Swift target | the Ubuntu 26.04 glibc 2.43 / libstdc++ 15 workaround (see docs/BUILDING.md). Goes away when swift.org ships a 26.04 toolchain; until then it is the one flag with no clean answer |

`glibcMathCompat` is now probe-gated (`needsGlibcMathCompat()`), so it is added only
where the known-bad pairing exists and macOS / pre-26.04 Linux consumers see a
package with no per-target flags at all. With the probe forced off, the only taint
a consumer reports is:

```
error: the target 'FlutterSwiftBridge' in product 'Flutter' contains unsafe build flags
```

That is the `-L`/`-rpath` row — one target, one cause, and the only thing between
here and a publishable package.

### The compat flags are still required — and this dev box lies about it

The clash does **not** reproduce on this machine: a minimal C++-interop package
that imports Foundation builds clean with no compat flags, as does all of `sdk/`
with the probe forced off, and `shell/` with its `glibcMathCompat` emptied.

**That is an artifact of this machine, and the flags must not be removed.** In a
clean Ubuntu 26.04 chroot — same Swift 6.2.4, same gcc 15.2.0-16ubuntu1, same
libstdc++-15-dev, byte-identical `cmath` — the same probe fails exactly as
documented:

```
/usr/include/c++/15/cmath:100:3: error: redefinition of 'acos'
```

The mechanism, from the full diagnostic: Foundation's `_CStdlib.h` does
`#include <math.h>`, which in C++ mode resolves to libstdc++'s *wrapper*
`/usr/include/c++/15/math.h` (that directory precedes `/usr/include`), and the
wrapper `#define`s `_GLIBCXX_MATH_H` and pulls `<cmath>` textually — against the
prebuilt `std` module. Hence the two flags: predefine the guard, force-include
glibc's real header.

The reason this box escapes it is that **`/usr/include/c++/15/math.h` has been
edited locally**:

```diff
-#if !defined __cplusplus || defined _GLIBCXX_INCLUDE_NEXT_C_HEADERS
+#if !defined __cplusplus || defined _GLIBCXX_INCLUDE_NEXT_C_HEADERS || defined __building_module
```

`__building_module` is a Clang builtin set while building a clang module, which is
precisely what the interop importer does — so the wrapper takes the plain-C path
and the collision never happens. `dpkg --verify libstdc++-15-dev` confirms it:
`??5?????? /usr/include/c++/15/math.h`, checksum diverging from the installed
package while still reporting version 15.2.0-16ubuntu1.

So the dev box silently disagrees with every clean machine, the .deb's users and
CI included. Anything concluded about `<cmath>` here is worthless without a chroot
check. The probe gate (`libstdc++ >= 15`) is correct and stays.

## Distribution: one bundle carrying framework + engine

Decided: ship the framework and the engine binaries as a single artifact rather
than asking consumers to install an engine package. `tools/make-bundle.sh` builds
it; `Package.swift` probes for `<package>/engine/lib` and uses it when present,
falling back to the sibling checkout for in-tree development.

    flutter-swift-linux-aarch64/
      Package.swift Sources/ Tests/ tools/ LICENSE .deps/
      engine/lib/     libflutter_engine.so, libflutter_linux_drm.so
      engine/share/   icudtl.dat, flutter_assets/

22 MB compressed with the release engine. Verified end to end: unpacked into a
directory with no engine source tree and no starling checkout, a consumer package
depending on it by path builds, `ldd` resolves `libflutter_engine.so` to the
bundle's own `engine/lib`, and the executable runs.

**This is a path dependency, not `.package(url:from:)`, and that is inherent.**
SwiftPM cannot carry a native *library* as a `binaryTarget` on Linux — XCFramework
is Apple-only, Linux artifactbundles hold executables — and pointing at the
bundled engine needs `-L`/`-rpath`, which are `.unsafeFlags`: rejected for
version-resolved dependencies, allowed for path dependencies. So bundling
**sidesteps** the `unsafeFlags` restriction instead of satisfying it, and the
`-L`/`-rpath` row above stops being a blocker.

Consequences worth keeping in view:

- No `swift package update` and no SwiftPM version resolution. This is a
  download-and-point SDK, the same shape as the Flutter SDK itself.
- The engine path is baked into consumers' RUNPATH, so moving an unpacked bundle
  means rebuilding. Noted in the bundle's README.
- The vendored bridge headers and the bundled `libflutter_engine.so` must ship
  together — they are the same ABI. `make-bundle.sh` refuses to build if
  `sync-vendored-headers.sh --check` reports drift.
- If versioned consumption is ever wanted as well, see the static-engine results
  below — that route now looks open.

## Static engine: tested, and it works

The question was whether the engine could be a static library so consumers link it
into their own binary instead of shipping a `.so`. Answer: yes, with two
non-obvious fixes. All of the following is measured on linux/aarch64, release.

**1. GN emits the archive, but incomplete.** Added
`static_library("flutter_engine_static_library")` with `complete_static_lib = true`
(the idiom Skia, Dart and SwiftShader already use in-tree) to
`shell/platform/embedder/BUILD.gn`. It builds in one `AR` step — the objects
already exist from the shared build.

It links against *nothing*, though: 6,465 undefined references. Cause is in
`build/config/BUILDCONFIG.gn`, which wraps `executable`, `loadable_module` and
`shared_library` to inject `//flutter/third_party/libcxx` — **but not
`static_library`**, which never links. The engine bundles its own libc++ under the
`std::_fl` ABI namespace, so ~3.5k definitions were simply absent. Naming the dep
explicitly in the target fixes it: 0 undefined references, links, runs.

**2. Symbol leakage is real, silent, and worse than a link error.** The shared
library gets its discipline from `--version-script=embedder_exports.lst`
(12 globs → 515 symbols). An archive is never linked, so the version script does
not apply: **63,919 global symbols**, including the vendored freetype, expat and
libjpeg.

This does not fail to link. It links and runs, having silently bound the consumer
to the *engine's vendored* freetype rather than the system one — verified by
symbol table, not assumed:

| archive | `FT_Init_FreeType` dynamic-undefined? | which freetype runs |
|---|---|---|
| non-localized | no | engine's vendored copy |
| localized | yes | system `libfreetype.so.6` |

`tools/make-static-engine.sh` fixes it in the only order that works:
`ld -r --whole-archive` to bind internal cross-references into one object, *then*
`objcopy --keep-global-symbols`. Localizing the archive directly instead breaks
it — sibling members stop seeing each other. The keep-list is derived from
`embedder_exports.lst` itself, so the two builds cannot drift. Result: 63,919 → 525
globals, matching the `.so`'s 515.

Cost: one combined object means the linker can no longer drop unused members.
`--gc-sections` more than recovers it — 54 MB → **29 MB** for the test binary.

**3. SE-0482 accepts it.** SwiftPM 6.2 took the archive as a `staticLibrary`
`binaryTarget` on Linux: parsed `info.json`, compiled Swift against the modulemap,
linked, ran. So versioned `.package(url:from:)` consumption is reachable.

The transitive-dependency restriction is the practical catch, and it is a
packaging problem, not a blocker — `.linkedLibrary` is a *safe* setting, so the
package can declare all of them itself. Of the 17 needed, 9 already resolve here
(`m dl pthread stdc++ drm gbm EGL GLESv2 xkbcommon`); 8 need `-dev` packages
installed (`fontconfig input udev freetype expat mtdev evdev wacom`). With those
present every one becomes a plain `.linkedLibrary` and the package carries **no
unsafe flags at all**.

**4. The C++ bridge works too.** SE-0482 says C interfaces only, but that
constrains the *binary target's own modulemap*, not what the archive may contain.
Putting only the `.a` and the C embedder header in the binary target, and leaving
`FlutterSwiftBridgeCxx` as an ordinary C++ source target, threads it: the bridge
headers compile from source in the package and their symbols
(275 `_ZN7flutter12swift_bridge*` definitions) resolve out of the archive.

Verified by construction and execution, not inspection. `sdk/Package.swift` was
rewired to drop `-L`/`-l`/`-rpath` for a `.binaryTarget`, and a probe that builds
a real C++ object under Swift ARC —

```swift
let p = Path()          // flutter::swift_bridge::PathBridge, SWIFT_SHARED_REFERENCE
p.fillType = .evenOdd
```

— links to a **42 MB binary with no `libflutter_engine.so` dependency at all**, and
prints `fillType = evenOdd`. The whole package builds in that configuration, not
just the probe.

### What is still untested

- **Remote consumption.** The binary target was attached with `path:`. True
  `.package(url:from:)` needs `url:` + `checksum:` on a hosted
  `.artifactbundle.zip` — same mechanism, but not exercised here, and the bundle
  is 109 MB.
- **The system libraries: settled.** Verified in the clean 26.04 chroot — with the
  right `-dev` packages, **all 17 link with a plain `-l`**, so every one becomes a
  safe `.linkedLibrary` and that entire source of unsafe flags disappears. The dev
  box needed 8 packages; a clean machine needs 13, because it also lacks `drm gbm
  EGL GLESv2 xkbcommon`:

      libdrm-dev libgbm-dev libegl-dev libgles-dev libxkbcommon-dev
      libfontconfig-dev libinput-dev libudev-dev libfreetype-dev
      libexpat1-dev libmtdev-dev libevdev-dev libwacom-dev

  That list is a consumer prerequisite and belongs in the bundle README.

  **But a fully flag-clean manifest on Ubuntu 26.04 is still out of reach**, because
  `glibcMathCompat` is genuinely required there (see above) and has no safe
  expression. On macOS and pre-26.04 Linux the manifest does go clean. So versioned
  consumption is reachable *off* 26.04 today, and on 26.04 only once the libstdc++
  wrapper or the toolchain is fixed upstream.
- **Runtime beyond construction.** Nothing here starts an engine, loads assets or
  renders. Only that the bridge links and objects construct.
- **macOS.** Untouched.
- **Extract the repo.** `git filter-repo`/subtree to keep history. starling-desktop
  then depends on it by path for dev, by version for release.
- **macOS parity.** `Package.swift` already has a macOS branch and a
  `FlutterMacOSBridge`, but nothing here verifies it; needs a machine and CI.
- **Decide what does not ship.** `macos-compat/` is a separate research project
  (running unmodified Mach-O macOS binaries on Linux) and does not belong in a
  general-purpose SDK. Also repo-specific: `plans/`, `tools/drm_screenshot.c`,
  `app/BlueScreenApp-Info.plist`, `test_*.py`, and the committed
  `.deps/lib/libglfw.so.3.4` blob that `GLFWBridge.h` reaches by relative path.
- **Generalise `$STARLING_AGENT_ENDPOINT`** into a neutral hook, or accept it as
  a harmless env-gated no-op.
