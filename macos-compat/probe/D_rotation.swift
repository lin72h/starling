import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View { Text("rot").rotationEffect(.degrees(45)) } }
