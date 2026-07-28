import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View { NavigationStack { Text("c").toolbar { Button("T") {} } } } }
