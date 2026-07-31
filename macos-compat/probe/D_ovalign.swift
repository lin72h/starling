import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View {
  var body: some View {
    VStack(spacing: 24) {
      Color.blue.frame(width: 200, height: 70).overlay(Text("TL"), alignment: .topLeading)
      Color.green.frame(width: 200, height: 70).overlay(Text("BR"), alignment: .bottomTrailing)
    }
  }
}
