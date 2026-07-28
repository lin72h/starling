// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
#if os(Linux)
import Glibc
#endif

// MARK: - FileEntry

/// Represents a file or directory entry with metadata.
struct FileEntry {
    let name: String
    let path: String
    let isDirectory: Bool
    let isSymlink: Bool
    let size: UInt64
    let modified: Date
    let permissions: String
    let owner: String

    /// File extension (lowercase, without dot). Empty for directories.
    var fileExtension: String {
        guard !isDirectory else { return "" }
        let ext = (name as NSString).pathExtension
        return ext.lowercased()
    }

    /// Icon character based on file type.
    var icon: String {
        if isDirectory { return "\u{1F4C1}" }  // 📁
        switch fileExtension {
        case "swift", "c", "cc", "cpp", "h", "py", "js", "ts", "rs", "go", "java", "rb", "sh":
            return "\u{1F4DD}"  // 📝 source code
        case "txt", "md", "json", "xml", "yaml", "yml", "toml", "ini", "cfg", "conf", "log":
            return "\u{1F4C4}"  // 📄 text
        case "png", "jpg", "jpeg", "gif", "bmp", "svg", "ico", "webp":
            return "\u{1F5BC}"  // 🖼 image
        case "mp3", "wav", "flac", "aac", "ogg", "m4a":
            return "\u{1F3B5}"  // 🎵 audio
        case "mp4", "mkv", "avi", "mov", "webm":
            return "\u{1F3AC}"  // 🎬 video
        case "zip", "tar", "gz", "bz2", "xz", "7z", "rar", "deb", "rpm":
            return "\u{1F4E6}"  // 📦 archive
        case "pdf":
            return "\u{1F4D1}"  // 📑 pdf
        case "so", "dylib", "a", "o":
            return "\u{2699}"   // ⚙ library
        default:
            return "\u{1F4C4}"  // 📄 generic file
        }
    }
}

// MARK: - SortColumn / SortOrder

enum SortColumn {
    case name
    case size
    case modified
    case type
}

enum SortOrder {
    case ascending
    case descending

    var toggled: SortOrder {
        return self == .ascending ? .descending : .ascending
    }

    var arrow: String {
        return self == .ascending ? " \u{25B2}" : " \u{25BC}"
    }
}

// MARK: - FileSystem

/// File system operations for the file explorer.
struct FileSystem {

    /// List contents of a directory.
    static func listDirectory(_ path: String, showHidden: Bool = false) -> [FileEntry] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else {
            return []
        }

        var entries: [FileEntry] = []
        for name in contents {
            if !showHidden && name.hasPrefix(".") { continue }

            let fullPath = (path as NSString).appendingPathComponent(name)

            // Check symlink before resolving
            var isSymlink = false
            if let attrs = try? fm.attributesOfItem(atPath: fullPath),
               let type = attrs[.type] as? FileAttributeType {
                isSymlink = (type == .typeSymbolicLink)
            }

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

            var size: UInt64 = 0
            var modified = Date()
            var perms = ""
            var owner = ""

            if let attrs = try? fm.attributesOfItem(atPath: fullPath) {
                size = attrs[.size] as? UInt64 ?? 0
                modified = attrs[.modificationDate] as? Date ?? Date()
                if let posix = attrs[.posixPermissions] as? Int {
                    perms = _formatPermissions(posix, isDir: isDir.boolValue)
                }
                owner = attrs[.ownerAccountName] as? String ?? ""
            }

            entries.append(FileEntry(
                name: name,
                path: fullPath,
                isDirectory: isDir.boolValue,
                isSymlink: isSymlink,
                size: size,
                modified: modified,
                permissions: perms,
                owner: owner
            ))
        }

        return entries
    }

    /// Sort entries: directories first, then by given column and order.
    static func sort(_ entries: [FileEntry], by column: SortColumn, order: SortOrder) -> [FileEntry] {
        return entries.sorted { a, b in
            // Directories always come first
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }

            let result: Bool
            switch column {
            case .name:
                result = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .size:
                result = a.size < b.size
            case .modified:
                result = a.modified < b.modified
            case .type:
                let extA = a.fileExtension
                let extB = b.fileExtension
                if extA == extB {
                    result = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                } else {
                    result = extA < extB
                }
            }

            return order == .ascending ? result : !result
        }
    }

    /// Filter entries by search query (case-insensitive name match).
    static func filter(_ entries: [FileEntry], query: String) -> [FileEntry] {
        guard !query.isEmpty else { return entries }
        let lower = query.lowercased()
        return entries.filter { $0.name.lowercased().contains(lower) }
    }

    // MARK: - File Operations

    /// Create a new directory. Returns nil on success, error message on failure.
    static func createDirectory(at path: String, name: String) -> String? {
        let fullPath = (path as NSString).appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(atPath: fullPath, withIntermediateDirectories: false)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Rename a file or directory. Returns nil on success, error message on failure.
    static func rename(at path: String, to newName: String) -> String? {
        let parent = (path as NSString).deletingLastPathComponent
        let newPath = (parent as NSString).appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(atPath: path, toPath: newPath)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Delete a file or directory. Returns nil on success, error message on failure.
    static func delete(at path: String) -> String? {
        do {
            try FileManager.default.removeItem(atPath: path)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Check if path is readable.
    static func isReadable(_ path: String) -> Bool {
        return FileManager.default.isReadableFile(atPath: path)
    }

    /// Free space (bytes) on the filesystem containing `path`, or nil if unavailable.
    static func freeSpace(at path: String) -> UInt64? {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: path),
              let free = attrs[.systemFreeSize] as? NSNumber else {
            return nil
        }
        return free.uint64Value
    }

    // MARK: - Formatting

    static func formatSize(_ bytes: UInt64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024.0
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024.0
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        let gb = mb / 1024.0
        return String(format: "%.1f GB", gb)
    }

    /// Finder-style date: "Today at 14:32", "Yesterday at 09:15", "6 Jul 2026 at 14:32".
    static func formatDate(_ date: Date) -> String {
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Today at " + time.string(from: date)
        }
        if cal.isDateInYesterday(date) {
            return "Yesterday at " + time.string(from: date)
        }
        let df = DateFormatter()
        df.dateFormat = "d MMM yyyy 'at' HH:mm"
        return df.string(from: date)
    }

    static func parentPath(_ path: String) -> String {
        let parent = (path as NSString).deletingLastPathComponent
        return parent.isEmpty ? "/" : parent
    }

    static func pathComponents(_ path: String) -> [(name: String, path: String)] {
        var components: [(name: String, path: String)] = []
        var current = path
        while current != "/" && !current.isEmpty {
            let name = (current as NSString).lastPathComponent
            components.insert((name: name, path: current), at: 0)
            current = (current as NSString).deletingLastPathComponent
        }
        components.insert((name: "/", path: "/"), at: 0)
        return components
    }

    // MARK: - Private

    private static func _formatPermissions(_ mode: Int, isDir: Bool) -> String {
        var s = isDir ? "d" : "-"
        let flags = ["r", "w", "x"]
        for i in (0..<3).reversed() {
            let shift = i * 3
            for j in 0..<3 {
                s += (mode >> (shift + 2 - j)) & 1 != 0 ? flags[j] : "-"
            }
        }
        return s
    }
}
