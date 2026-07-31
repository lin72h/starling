import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View {
  RadialGradient(colors: [.blue, .green], center: .center, startRadius: 0, endRadius: 300) } }
