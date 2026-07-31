import SwiftUI
import Combine
class Model: ObservableObject { @Published var c = 0 }
@main struct A: App { @StateObject var m = Model()
  var body: some Scene { WindowGroup { CV().environmentObject(m) } } }
struct CV: View { @EnvironmentObject var m: Model
  var body: some View { VStack { Text("n=\(m.c)"); Button("inc") { m.c += 1 } } } }
