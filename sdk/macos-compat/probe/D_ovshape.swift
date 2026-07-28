import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View {
  Text("Shaped Overlay").padding()
    .overlay(LinearGradient(colors: [.red, .yellow], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 16)) } }
