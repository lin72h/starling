import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var on = true
  var body: some View { Toggle("sw", isOn: $on).toggleStyle(.switch) } }
