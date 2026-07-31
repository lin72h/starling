import SwiftUI

// A comprehensive SwiftUI layout/controls probe for the macos-compat breadth work.
// Compiled UNMODIFIED with Apple's toolchain (like probe/Hello) and run through
// machold on Linux/arm64. Each section is independently commentable so the
// reconstruction can be grown one group at a time; every view here maps cleanly
// onto a Flutter widget (the CompatHost translation target):
//
//   VStack/HStack/ZStack -> Column/Row/Stack     Spacer     -> Spacer/Expanded
//   ScrollView           -> SingleChildScrollView Divider   -> Divider
//   Image(systemName:)   -> Icon                  Toggle    -> Switch
//   TextField            -> TextField             Slider    -> Slider
//   .frame/.padding      -> SizedBox/Padding      .background/.cornerRadius -> Container
//   .font/.foregroundColor -> TextStyle           ForEach   -> [Widget] in a flex
//
// @main entry, App/Scene/WindowGroup: identical shape to Hello (already proven).

@main
struct GalleryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var count = 0
    @State private var enabled = true
    @State private var name = "Flutter"
    @State private var volume = 0.5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Typography: font, weight, color ─────────────────────────
                Group {
                    Text("SwiftUI Gallery")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Comprehensive layout & controls probe")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Divider()

                // ── HStack + Spacer + Image + alignment ─────────────────────
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Rating")
                    Spacer()
                    Text("4.9").bold()
                }

                // ── ZStack overlay + background + cornerRadius + frame ───────
                ZStack {
                    Color.blue
                        .frame(height: 60)
                        .cornerRadius(8)
                    Text("ZStack overlay")
                        .foregroundColor(.white)
                }

                // ── @State counter (the Hello interaction, in an HStack) ─────
                HStack {
                    Text("Count: \(count)")
                    Spacer()
                    Button("Increment") { count += 1 }
                }

                // ── Controls bound to @State ────────────────────────────────
                Toggle("Enabled", isOn: $enabled)
                TextField("Name", text: $name)
                Slider(value: $volume)

                // ── ForEach grid of colored boxes (nested stacks) ───────────
                VStack(spacing: 8) {
                    ForEach(0..<2) { _ in
                        HStack(spacing: 8) {
                            ForEach(0..<3) { _ in
                                Color.green
                                    .frame(width: 60, height: 40)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}
