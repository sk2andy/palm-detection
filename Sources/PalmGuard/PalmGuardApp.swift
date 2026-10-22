import AppKit
import SwiftUI

@main
struct PalmGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("PalmGuard", id: "settings") {
            SettingsView(model: model)
                .onAppear { model.startPreview() }
        }
        .defaultSize(width: 780, height: 820)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.isEnabled ? "hand.raised.fill" : "hand.raised")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

private struct MenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.status)
        Button(model.isEnabled ? "Schutz pausieren" : "Schutz aktivieren") {
            model.toggleProtection()
        }
        Divider()
        Button("Fläche & Einstellungen …") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Trackpad neu verbinden") { model.reconnect() }
        Divider()
        Button("PalmGuard beenden") {
            model.shutdown()
            NSApp.terminate(nil)
        }
    }
}
