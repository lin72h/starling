import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View {
  Text("Overlay").padding()
    .overlay(LinearGradient(colors: [.red, .yellow], startPoint: .leading, endPoint: .trailing)) } }
