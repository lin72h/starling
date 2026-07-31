import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var show = false
  var body: some View { Button("open") { show = true }.sheet(isPresented: $show) { Text("SHEET") } } }
