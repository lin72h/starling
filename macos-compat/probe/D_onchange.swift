import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var n = 0
  var body: some View { VStack { Text("n=\(n)"); Button("b") { n += 1 } }.onChange(of: n) { o, w in } } }
