// Bisect probe A — console (no SwiftUI): isolates Foundation Data + JSONDecoder from the
// render path. Build on a Mac, run under machold on Linux. See linux/FOUNDATION-ISSUE.md.
//   xcrun swiftc -target arm64-apple-macos14.0 -sdk "$(xcrun --show-sdk-path)" -O     -o JsonProbe_O     JsonProbe.swift
//   xcrun swiftc -target arm64-apple-macos14.0 -sdk "$(xcrun --show-sdk-path)" -Onone -o JsonProbe_Onone JsonProbe.swift
import Foundation

struct Product: Codable { let id: Int; let name: String; let price: Double }

let json = Data(#"[{"id":1,"name":"Coffee","price":3.5},{"id":2,"name":"Bagel","price":2.25},{"id":3,"name":"Orange Juice","price":4.0}]"#.utf8)
let ps = (try? JSONDecoder().decode([Product].self, from: json)) ?? []
print("decoded \(ps.count): \(ps.map { $0.name })")
