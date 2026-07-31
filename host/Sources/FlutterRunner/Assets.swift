// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(Linux)
import Foundation
import Glibc

/// Where the engine's data files are.
///
/// Every embedder has to hand `FlutterProjectArgs` two paths: `flutter_assets`
/// (manifests, shaders, the engine's NOTICES) and `icudtl.dat` (ICU, without
/// which the engine aborts in `icu_util.cc` before it draws anything).
///
/// Hosts in this tree each grew their own answer — a relative path into the
/// engine checkout, differing per host by how deep the caller happened to be
/// (`../engine/…` in one, `../../engine/…` in another). Relative paths resolve
/// against the *current working directory*, so the same binary works when run
/// from its package directory and dies when run from anywhere else:
///
///     [FATAL:flutter/fml/icu_util.cc(97)] Check failed: context->IsValid().
///     Tried: ../../engine/src/out/host_debug/icudtl.dat
///
/// That is not something an app author should have to know about, so this
/// resolves the pair from the *executable's* location and the environment,
/// never from the cwd, and reports what it tried when it comes up empty.
public enum FlutterAssets {

    /// The two paths the embedder needs.
    public struct Paths: Sendable {
        public let assets: String
        public let icuData: String
    }

    /// Resolves the asset paths, or nil if no candidate holds both files.
    ///
    /// Order, first hit wins:
    ///  1. `FLUTTER_ASSETS_DIR` + `FLUTTER_ICU_DATA` — set both to place them
    ///     independently; nothing else is consulted.
    ///  2. `FLUTTER_ENGINE_OUT` — an engine build directory, the knob the
    ///     desktop already forwards to its child apps.
    ///  3. Beside the executable, then the packaged `share/` layouts. This is
    ///     what a distributed app should rely on.
    ///  4. The source tree found by walking up from the executable, pairing
    ///     its vendored `build/flutter_assets` with the engine's `icudtl.dat`.
    ///     That pairing is what makes a freshly built `.build/release/App` run
    ///     with no environment set at all.
    public static func locate() -> Paths? {
        var tried: [String] = []
        for candidate in candidates(recording: &tried) {
            if isDirectory(candidate.assets), isFile(candidate.icuData) {
                return candidate
            }
        }
        lastSearch = tried
        return nil
    }

    /// The directories `locate()` looked in, for an error message worth reading.
    public private(set) nonisolated(unsafe) static var lastSearch: [String] = []

    // MARK: - Candidates

    private static func candidates(recording tried: inout [String]) -> [Paths] {
        var out: [Paths] = []
        let env = ProcessInfo.processInfo.environment

        // An env var set to "" is not a request to use the empty path — the
        // engine's own knobs are read with bare getenv() and treat "" as set,
        // which is how FLUTTER_DRM_CONNECTOR="" once made the connector filter
        // reject every output. Treat empty as absent, here and below.
        func value(_ key: String) -> String? {
            guard let v = env[key], !v.isEmpty else { return nil }
            return v
        }

        if let assets = value("FLUTTER_ASSETS_DIR"), let icu = value("FLUTTER_ICU_DATA") {
            tried.append("\(assets) + \(icu)  (FLUTTER_ASSETS_DIR/FLUTTER_ICU_DATA)")
            return [Paths(assets: assets, icuData: icu)]
        }

        var roots: [String] = []
        if let engineOut = value("FLUTTER_ENGINE_OUT") { roots.append(engineOut) }

        if let exeDir = executableDirectory() {
            roots.append(exeDir)                                  // app + data side by side
            roots.append("\(exeDir)/../share/starling")           // staged tree
            roots.append("\(exeDir)/../../share/starling")
            roots.append("\(exeDir)/../../../share/starling")     // /usr/lib/starling/apps
            roots.append("\(exeDir)/../share")
        }
        roots.append("/usr/share/starling")

        for root in roots {
            let paths = Paths(assets: "\(root)/flutter_assets", icuData: "\(root)/icudtl.dat")
            tried.append(root)
            out.append(paths)
        }

        // The source tree, where the two files do NOT live together: the
        // engine build directory has icudtl.dat, while flutter_assets is
        // vendored in the desktop repo at build/flutter_assets. Nothing
        // assembles them into one directory until stage.sh runs, so a freshly
        // built example has to pair them across roots — otherwise `swift build
        // && ./MyApp` only works on a machine that happens to have the desktop
        // installed system-wide, which is the least representative machine
        // there is.
        if let exeDir = executableDirectory(), let repo = repoRoot(above: exeDir) {
            tried.append("\(repo)/build/flutter_assets + <engine>/icudtl.dat")
            for config in ["host_debug", "host_release"] {
                out.append(Paths(
                    assets: "\(repo)/build/flutter_assets",
                    icuData: "\(repo)/engine/src/out/\(config)/icudtl.dat"))
            }
        }
        return out
    }

    /// Walks up from `start` for the desktop source tree: the directory that
    /// holds both the vendored assets and the engine symlink.
    private static func repoRoot(above start: String) -> String? {
        var dir = start
        for _ in 0..<12 {
            if isDirectory("\(dir)/build/flutter_assets"), isDirectory("\(dir)/engine/src") {
                return dir
            }
            let parent = (dir as NSString).deletingLastPathComponent
            if parent.isEmpty || parent == dir { break }
            dir = parent
        }
        return nil
    }

    /// The directory holding this process's executable, resolved through
    /// /proc/self/exe so it is absolute and independent of how we were invoked.
    private static func executableDirectory() -> String? {
        var buf = [CChar](repeating: 0, count: 4096)
        let n = readlink("/proc/self/exe", &buf, buf.count - 1)
        guard n > 0 else { return nil }
        buf[n] = 0
        let exe = String(cString: buf)
        return (exe as NSString).deletingLastPathComponent
    }

    // MARK: - Probes

    private static func isDirectory(_ path: String) -> Bool {
        var st = stat()
        guard stat(path, &st) == 0 else { return false }
        return (st.st_mode & S_IFMT) == S_IFDIR
    }

    private static func isFile(_ path: String) -> Bool {
        var st = stat()
        guard stat(path, &st) == 0 else { return false }
        return (st.st_mode & S_IFMT) == S_IFREG
    }
}
#endif
