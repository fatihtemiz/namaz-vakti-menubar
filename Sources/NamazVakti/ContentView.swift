import SwiftUI

/// Menü barındaki ikona tıklayınca açılan panel.
struct ContentView: View {
    @EnvironmentObject var manager: PrayerTimesManager
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Başlık: şehir + sıradaki vakit
            VStack(alignment: .leading, spacing: 2) {
                Text(manager.displayCityName.isEmpty ? loc("Namaz Vakti", "Prayer Times") : manager.displayCityName)
                    .font(.headline)
                if !manager.nextName.isEmpty {
                    Text(loc("Sıradaki: ", "Next: ") + "\(manager.nextName) — \(manager.nextTime)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(loc("\(manager.remaining) kaldı", "\(manager.remaining) left"))
                        .font(.system(.title2, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                }
            }

            if !manager.todayRows.isEmpty {
                Divider()
                VStack(spacing: 4) {
                    ForEach(manager.todayRows, id: \.name) { row in
                        HStack {
                            Text(row.name)
                                .fontWeight(row.isNext ? .semibold : .regular)
                            Spacer()
                            Text(row.time)
                                .monospacedDigit()
                                .fontWeight(row.isNext ? .semibold : .regular)
                        }
                        .foregroundStyle(row.isNext ? Color.accentColor : .primary)
                    }
                }
            }

            if !manager.status.isEmpty {
                Text(manager.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 12) {
                Toggle(loc("Saniyeler", "Seconds"), isOn: $manager.showSeconds)
                Spacer(minLength: 0)
                Toggle(loc("Kısa adlar", "Short names"), isOn: $manager.useAbbreviations)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .font(.callout)
            .lineLimit(1)

            HStack {
                Button {
                    Task { await manager.refresh() }
                } label: {
                    Label(loc("Yenile", "Refresh"), systemImage: "arrow.clockwise")
                }
                .disabled(manager.isLoading)

                Spacer()

                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label(loc("Ayarlar", "Settings"), systemImage: "gearshape")
                }

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label(loc("Çık", "Quit"), systemImage: "power")
                }
            }
            .buttonStyle(.plain)
            .labelStyle(.titleAndIcon)
        }
        .padding(14)
        .frame(width: 280)
    }
}
