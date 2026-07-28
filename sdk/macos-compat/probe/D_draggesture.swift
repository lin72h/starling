import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var n = 0
  var body: some View { Text("d=\(n)").gesture(DragGesture().onChanged { _ in n += 1 }) } }
