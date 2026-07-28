import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var on = false
  var body: some View { VStack { if on { Text("shown").transition(.opacity) }; Button("t") { on.toggle() } } } }
