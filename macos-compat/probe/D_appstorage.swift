import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @AppStorage("k") var v = 7
  var body: some View { Text("v=\(v)") } }
