import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View {
  VStack(spacing: 16) {
    Text("Rect").frame(width: 120, height: 44).background(Color.blue, in: Rectangle())
    Text("Capsule").frame(width: 120, height: 44).background(Color.green, in: Capsule())
    Color.red.frame(width: 64, height: 64).clipShape(Circle())
    Color.orange.frame(width: 120, height: 60).clipShape(Ellipse())
  }
} }
