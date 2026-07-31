import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var show = false
  var body: some View { Button("go") { show = true }.alert("Oops", isPresented: $show) { Button("OK") {} } } }
