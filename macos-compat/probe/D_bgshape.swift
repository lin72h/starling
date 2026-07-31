import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View {
  Text("Shaped BG").padding()
    .background(Color.blue, in: RoundedRectangle(cornerRadius: 16)) } }
