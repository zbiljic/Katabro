import AppKit
import SwiftUI

struct MenuBarView: View {
    let defaultBrowserClient: DefaultBrowserClient
    let onboardingCoordinator: OnboardingWindowCoordinator
    let pickerCoordinator: BrowserPickerCoordinator
    let preferencesStore: PreferencesStore

    var body: some View {
        Button("Open Test Picker") {
            guard let url = URL(string: "https://example.com") else {
                return
            }

            pickerCoordinator.handle(url)
        }
        .accessibilityIdentifier(
            AccessibilityIdentifier.menuOpenTestPicker
        )

        Button(
            preferencesStore.hasCompletedOnboarding
                ? "Setup Guide…"
                : "Finish Setup…"
        ) {
            onboardingCoordinator.present()
        }
        .accessibilityIdentifier(
            AccessibilityIdentifier.menuSetupGuide
        )

        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",", modifiers: .command)
        .accessibilityIdentifier(
            AccessibilityIdentifier.menuSettings
        )

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
        .accessibilityIdentifier(
            AccessibilityIdentifier.menuDefaultBrowserStatus
        )

        Divider()

        Button("Quit Katabro") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
        .accessibilityIdentifier(
            AccessibilityIdentifier.menuQuit
        )
    }
}
