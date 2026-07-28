import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @SceneStorage("k") var v = 3
  var body: some View { Text("v=\(v)") } }
