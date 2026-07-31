import Foundation
let d = Data(#"[{"id":1,"name":"Coffee"}]"#.utf8)
let n = d.withUnsafeBytes { $0.count }
print("ub=\(n)")
