// Bisect probe B — console (no SwiftUI, no JSONDecoder): narrows to Data construct + read
// (Data.withUnsafeBytes / _Representation) alone. Build on a Mac, run under machold on Linux.
// See linux/FOUNDATION-ISSUE.md.
//   xcrun swiftc -target arm64-apple-macos14.0 -sdk "$(xcrun --show-sdk-path)" -O     -o DataProbe_O     DataProbe.swift
//   xcrun swiftc -target arm64-apple-macos14.0 -sdk "$(xcrun --show-sdk-path)" -Onone -o DataProbe_Onone DataProbe.swift
import Foundation

let d = Data(#"[{"id":1,"name":"Coffee"}]"#.utf8)
let n = d.withUnsafeBytes { $0.count }          // exercises Data.withUnsafeBytes / _Representation
let sum = d.reduce(0) { $0 + Int($1) }
print("count=\(d.count) ubcount=\(n) sum=\(sum)")
