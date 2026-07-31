import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var f = true
  var body: some View { VStack { if f { Text("on") } else { Text("off") } } } }
