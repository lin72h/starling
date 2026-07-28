// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A freedesktop-style key file: `[Group]` headers, `Key=Value` lines,
/// `#` comments.
///
/// The same parser reads three things, which is the point: our own catalog
/// records, the records `app-install` writes, and the `.desktop` entries the
/// host's packages ship. Using the format everything else on the system
/// already uses means `app-install` can write a record with `printf` and you
/// can read one with `cat`.
public struct KeyFile: Sendable {

    public private(set) var values: [String: String] = [:]

    /// Reads `path`, keeping only the keys in `group` (the first group in the
    /// file when nil). Group scoping matters for `.desktop` files: the
    /// `[Desktop Action …]` groups carry their own `Icon`/`Exec` keys and must
    /// not win over `[Desktop Entry]`.
    public init?(path: String, group: String? = nil) {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        self.init(text: text, group: group)
    }

    public init(text: String, group: String? = nil) {
        var current: String? = nil
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("["), line.hasSuffix("]") {
                current = String(line.dropFirst().dropLast())
                continue
            }
            guard let eq = line.firstIndex(of: "=") else { continue }
            // No group seen yet, or we're in the wanted one. With `group` nil
            // the first group claims the file and later ones are ignored.
            if let want = group {
                guard current == want else { continue }
            } else if let seen = current, let first = firstGroup, seen != first {
                continue
            }
            if firstGroup == nil { firstGroup = current }
            let key = String(line[line.startIndex..<eq]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: eq)...])
                .trimmingCharacters(in: .whitespaces)
            if values[key] == nil { values[key] = value }
        }
    }

    private var firstGroup: String? = nil

    public func string(_ key: String) -> String? {
        guard let v = values[key], !v.isEmpty else { return nil }
        return v
    }

    /// A `;`-separated list, the freedesktop convention. Empty entries drop
    /// out, so a trailing `;` is harmless.
    public func list(_ key: String) -> [String] {
        guard let v = string(key) else { return [] }
        return v.split(separator: ";").map {
            $0.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
    }

    public func int(_ key: String) -> Int? {
        guard let v = string(key) else { return nil }
        return Int(v)
    }

    /// A hex colour with no `#` or alpha (`737B89`), as the catalog writes it.
    public func rgb(_ key: String) -> UInt32? {
        guard let v = string(key) else { return nil }
        return UInt32(v.hasPrefix("#") ? String(v.dropFirst()) : v, radix: 16)
    }

    // MARK: - Writing

    /// Serialize a record. Values are written verbatim: keys are ours and
    /// values come from the filesystem, so there is nothing to escape beyond
    /// newlines, which would break the format.
    public static func serialize(group: String, _ pairs: [(String, String)]) -> String {
        var out = "[\(group)]\n"
        for (k, v) in pairs where !v.isEmpty {
            out += "\(k)=\(v.replacingOccurrences(of: "\n", with: " "))\n"
        }
        return out
    }
}
