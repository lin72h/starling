import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View { Circle().stroke(Color.red, lineWidth: 3).frame(width: 40, height: 40) } }
