import SwiftUI
import Foundation

// Sophisticated in-scope SwiftUI app for the macos-compat render-path stress test.
// Built UNMODIFIED with Apple's toolchain, run through machold on Linux/arm64.
// Deliberately stays within the reconstructed surface (no if/else/for in @ViewBuilder,
// no .background/.frame(maxWidth:)/NavigationStack/List) but goes far deeper than
// Gallery: helper-function subviews, computed sub-views, nested ForEach, ZStack
// overlays with alignment, every proven modifier chained, 6 @State vars.

@main
struct DashboardApp: App {
    var body: some Scene { WindowGroup { DashboardView() } }
}

struct Activity: Identifiable {
    let id: Int
    let title: String
    let icon: String
    let value: String
    let progress: Double
}

struct DashboardView: View {
    @State private var steps = 7421
    @State private var darkMode = true
    @State private var notifications = false
    @State private var userName = "Alex"
    @State private var intensity = 0.6
    @State private var activities: [Activity] = [
        Activity(id: 0, title: "Running",  icon: "figure.run",  value: "5.2 km", progress: 0.8),
        Activity(id: 1, title: "Cycling",  icon: "bicycle",     value: "12 km",  progress: 0.5),
        Activity(id: 2, title: "Swimming", icon: "drop.fill",   value: "800 m",  progress: 0.3),
        Activity(id: 3, title: "Yoga",     icon: "figure.yoga", value: "45 min", progress: 0.9),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statsRow
                weekStreak
                Divider()
                activitySection
                Divider()
                settingsSection
                footer
            }
            .padding()
        }
    }

    // Header: ZStack card — color background with overlaid welcome text.
    var header: some View {
        ZStack(alignment: .leading) {
            Color.blue
                .frame(height: 110)
                .cornerRadius(16)
            VStack(alignment: .leading, spacing: 6) {
                Text("Good morning,")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(userName)
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
            }
            .padding()
        }
    }

    // Three stat cards in a row, each a ZStack(bg + VStack).
    var statsRow: some View {
        HStack(spacing: 12) {
            statCard(icon: "flame.fill", label: "Steps",  value: "\(steps)", tint: .orange)
            statCard(icon: "heart.fill", label: "BPM",    value: "72",       tint: .red)
            statCard(icon: "bolt.fill",  label: "Energy", value: "340",      tint: .yellow)
        }
    }

    func statCard(icon: String, label: String, value: String, tint: Color) -> some View {
        ZStack {
            Color.secondary
                .frame(width: 104, height: 104)
                .cornerRadius(12)
            VStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(tint)
                Text(value).font(.title).fontWeight(.bold)
                Text(label).font(.caption).foregroundColor(.secondary)
            }
            .padding(8)
        }
    }

    // Nested ForEach: a 7-day streak strip of small boxes.
    var weekStreak: some View {
        HStack(spacing: 6) {
            ForEach(0..<7) { _ in
                Color.green
                    .frame(width: 36, height: 36)
                    .cornerRadius(8)
            }
        }
    }

    var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Activities").font(.headline)
            ForEach(activities) { a in
                HStack(spacing: 12) {
                    Image(systemName: a.icon).foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.title).fontWeight(.semibold)
                        Text(a.value).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(Int(a.progress * 100))%").fontWeight(.bold)
                }
                .padding(10)
                .cornerRadius(10)
            }
        }
    }

    var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.headline)
            Toggle("Dark Mode", isOn: $darkMode)
            Toggle("Notifications", isOn: $notifications)
            HStack {
                Text("Intensity")
                Spacer()
                Text("\(Int(intensity * 100))%").foregroundColor(.secondary)
            }
            Slider(value: $intensity)
            TextField("Display name", text: $userName)
        }
    }

    var footer: some View {
        HStack {
            Button("Reset") { steps = 0 }
            Spacer()
            Button("Add 1000 Steps") { steps += 1000 }
        }
        .padding(.top)
    }
}
