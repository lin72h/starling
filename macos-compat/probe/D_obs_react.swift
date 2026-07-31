import SwiftUI
import Combine
class M: ObservableObject { @Published var c = 0 }
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @StateObject var m = M()
  var body: some View {
    VStack {
      Text("\(m.c)")
      Button("inc") { m.c += 1 }
    }
  }
}
