import SwiftUI

/// Menü barındaki ikona tıklayınca açılan panel.
struct ContentView: View {
    @EnvironmentObject var manager: PrayerTimesManager
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Başlık: şehir + sıradaki vakit
            VStack(alignment: .leading, spacing: 2) {
                Text(manager.cityName.isEmpty ? "Namaz Vakti" : manager.cityName)
                    .font(.headline)
                if !manager.nextName.isEmpty {
                    Text("Sıradaki: \(manager.nextName) — \(manager.nextTime)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(manager.remaining + " kaldı")
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

            Toggle("Vakit adlarını kısalt", isOn: $manager.useAbbreviations)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.callout)

            HStack {
                Button {
                    Task { await manager.refresh() }
                } label: {
                    Label("Yenile", systemImage: "arrow.clockwise")
                }
                .disabled(manager.isLoading)

                Spacer()

                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Ayarlar", systemImage: "gearshape")
                }

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Çık", systemImage: "power")
                }
            }
            .buttonStyle(.plain)
            .labelStyle(.titleAndIcon)
        }
        .padding(14)
        .frame(width: 260)
    }
}
