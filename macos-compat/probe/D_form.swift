import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View { Form { Section("S") { Text("row1"); Text("row2") } } } }
