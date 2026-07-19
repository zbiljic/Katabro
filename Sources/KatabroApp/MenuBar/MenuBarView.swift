import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow)
    private var openWindow

    let defaultBrowserClient: DefaultBrowserClient
    let pickerCoordinator: BrowserPickerCoordinator
    let preferencesStore: PreferencesStore

    var body: some View {
        Button("Open Test Picker") {
            guard let url = URL(string: "https://example.com") else {
                return
            }

            pickerCoordinator.handle(url)
        }

        Button(
            preferencesStore.hasCompletedOnboarding
                ? "Setup Guide…"
                : "Finish Setup…"
        ) {
            openWindow(
                id: "onboarding"
            )
        }

        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Label(
            defaultBrowserClient.statusDescription,
            systemImage: defaultBrowserClient.status == .current
                ? "checkmark.circle.fill"
                : "exclamationmark.circle"
        )
        .foregroundStyle(
            defaultBrowserClient.status == .current ? .green : .secondary
        )

        Divider()

        Button("Quit Katabro") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
