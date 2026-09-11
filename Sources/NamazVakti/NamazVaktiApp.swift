import SwiftUI
import AppKit

@main
struct NamazVaktiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var manager = PrayerTimesManager()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(manager)
        } label: {
            // Menü barındaki metin — geri sayım burada canlı güncellenir (ikonsuz).
            Text(manager.menuTitle)
                .onAppear { manager.start() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(manager)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock ikonu olmayan bir menü bar (accessory) uygulaması olarak çalış.
        NSApp.setActivationPolicy(.accessory)
    }
}
