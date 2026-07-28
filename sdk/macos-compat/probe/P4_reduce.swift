import Foundation
let d = Data(#"[{"id":1,"name":"Coffee"}]"#.utf8)
let sum = d.reduce(0) { $0 + Int($1) }
print("sum=\(sum)")
