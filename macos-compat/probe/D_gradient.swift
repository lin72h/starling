import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View {
  LinearGradient(colors: [.blue, .green], startPoint: .top, endPoint: .bottom) } }
