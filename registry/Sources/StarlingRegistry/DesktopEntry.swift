// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The freedesktop side of app identity: an installed app's `.desktop` entry
/// and the icon theme.
///
/// Starling ships no third-party app artwork. Those marks (Chrome's disc, VS
/// Code's ribbon) are trademarks of their owners, and redistributing them in
/// the .deb is not something their licences cover — the MIT licence on VS
/// Code's source explicitly carves its logo out. So the dock reads the icon
/// from the copy the user installed, through the lookup every other desktop
/// uses: the app's `.desktop` entry names an icon, and the icon theme
/// directories say where it lives.
///
/// The same file answers the identity question. `StartupWMClass` is the value
/// a window's `xdg_toplevel.set_app_id` carries — it exists precisely so a
/// desktop can tie a window back to the app that launched it, which is the
/// job the dock needs done.
public enum DesktopEntry: Sendable {

    /// What an app's `.desktop` entry tells us about it on this host.
    public struct Resolved: Sendable {
        public let desktopFile: String
        /// `StartupWMClass`, else the entry's own basename — which is what a
        /// well-behaved Wayland client reports when it declares no override.
        public let wmClass: String
        /// Absolute path to a raster icon, when one exists. Nil for
        /// SVG-only installs: the engine's codecs decode raster only.
        public let iconPath: String?
        public let name: String?

        public init(desktopFile: String, wmClass: String, iconPath: String?,
                    name: String?) {
            self.desktopFile = desktopFile
            self.wmClass = wmClass
            self.iconPath = iconPath
            self.name = name
        }
    }

    /// Icon sizes worth having, best first. The dock tile is 256px at 2x, so
    /// 256 is ideal and anything above it is downscaled for nothing — but a
    /// too-large icon still beats a too-small one, hence 512 before 96.
    static let sizes = [256, 192, 128, 512, 96, 64, 48, 32]

    /// XDG data directories, most specific first: the user's own, then
    /// XDG_DATA_DIRS, then the snap and flatpak export roots.
    ///
    /// `home` is passed in rather than read from the environment because the
    /// two callers disagree about whose home matters: the shell may run as
    /// root while the session belongs to a user, and `app-install` runs as
    /// root under pkexec.
    public static func dataDirs(home: String? = nil) -> [String] {
        let env = ProcessInfo.processInfo.environment
        var dirs: [String] = []

        if let dataHome = env["XDG_DATA_HOME"], !dataHome.isEmpty {
            dirs.append(dataHome)
        } else if let h = home ?? env["HOME"], !h.isEmpty {
            dirs.append(h + "/.local/share")
        }

        let raw = env["XDG_DATA_DIRS"].flatMap { $0.isEmpty ? nil : $0 }
            ?? "/usr/local/share:/usr/share"
        dirs.append(contentsOf: raw.split(separator: ":").map(String.init))

        // Not in XDG_DATA_DIRS for a DRM session, but this is where snap and
        // flatpak put their exports.
        dirs.append("/var/lib/snapd/desktop")
        dirs.append("/var/lib/flatpak/exports/share")
        return dirs
    }

    /// Resolve the first of `entries` that exists on this host.
    public static func resolve(entries: [String], home: String? = nil) -> Resolved? {
        let dirs = dataDirs(home: home)
        for entry in entries {
            guard let path = findDesktopFile(entry, in: dirs),
                  let kf = KeyFile(path: path, group: "Desktop Entry")
            else { continue }
            let iconValue = kf.string("Icon")
            let icon = iconValue.flatMap { resolveIcon($0, in: dirs) }
            return Resolved(
                desktopFile: path,
                wmClass: kf.string("StartupWMClass") ?? entry,
                iconPath: icon,
                name: kf.string("Name"))
        }
        // No usable entry — try the basenames as bare icon names. Snap and
        // flatpak layouts sometimes land the icon without a matching entry
        // where we looked.
        for entry in entries {
            if let icon = findIcon(named: entry, in: dirs) {
                return Resolved(desktopFile: "", wmClass: entry,
                                iconPath: icon, name: nil)
            }
        }
        return nil
    }

    /// An `Icon=` value, which is either an absolute path or a theme name.
    public static func resolveIcon(_ value: String, in dirs: [String]) -> String? {
        if value.hasPrefix("/") {
            return isRaster(value) && FileManager.default.fileExists(atPath: value)
                ? value : nil
        }
        return findIcon(named: value, in: dirs)
    }

    static func findDesktopFile(_ basename: String, in dirs: [String]) -> String? {
        let name = basename.hasSuffix(".desktop") ? basename : basename + ".desktop"
        for dir in dirs {
            let p = "\(dir)/applications/\(name)"
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        return nil
    }

    static func isRaster(_ path: String) -> Bool {
        let p = path.lowercased()
        return p.hasSuffix(".png") || p.hasSuffix(".jpg") || p.hasSuffix(".jpeg")
    }

    /// Search the icon theme dirs, then pixmaps, for a raster icon.
    static func findIcon(named name: String, in dirs: [String]) -> String? {
        let fm = FileManager.default
        for dir in dirs {
            for size in sizes {
                for sub in ["apps", "devices"] {
                    let p = "\(dir)/icons/hicolor/\(size)x\(size)/\(sub)/\(name).png"
                    if fm.fileExists(atPath: p) { return p }
                }
            }
        }
        // Legacy location, and where Chrome's .deb actually puts its icon.
        for dir in dirs {
            for ext in ["png", "jpg"] {
                let p = "\(dir)/pixmaps/\(name).\(ext)"
                if fm.fileExists(atPath: p) { return p }
            }
        }
        return nil
    }
}
