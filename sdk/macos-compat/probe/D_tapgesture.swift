import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var n = 0
  var body: some View { Text("n=\(n)").onTapGesture { n += 1 } } }
