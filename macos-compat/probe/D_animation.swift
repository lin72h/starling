import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var n = 0
  var body: some View { VStack { Text("n=\(n)").animation(.default, value: n); Button("go") { withAnimation { n += 1 } } } } }
