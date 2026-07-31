import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var s = "wait"
  var body: some View { Text(s).task { s = "done" } } }
