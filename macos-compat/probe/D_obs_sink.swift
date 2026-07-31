import SwiftUI
import Combine
class M: ObservableObject { @Published var c = 7; @Published var label = "init" }
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @StateObject var m = M()
  var body: some View {
    Text(m.label).onAppear { _ = m.$c.sink { v in m.label = "got \(v)" } }
  }
}
