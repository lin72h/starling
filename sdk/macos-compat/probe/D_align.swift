import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View {
  var body: some View {
    VStack(spacing: 24) {
      VStack(alignment: .leading) { Text("Lx"); Text("Leading wide") }
      VStack(alignment: .center) { Text("Cx"); Text("Center wide") }
      VStack(alignment: .trailing) { Text("Tx"); Text("Trailing wide") }
    }
  }
}
