import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View {
  var body: some View {
    VStack(alignment: .trailing) {
      Text("x")
      ForEach(0..<2) { i in Text("foreach row \(i)") }
    }
  }
}
