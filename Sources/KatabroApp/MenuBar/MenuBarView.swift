import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openSettings)
    private var openSettings

    let clipboardURLClient: ClipboardURLClient
    let defaultBrowserClient: DefaultBrowserClient
    let onboardingCoordinator: OnboardingWindowCoordinator
    let pickerCoordinator: BrowserPickerCoordinator
    let preferencesStore: PreferencesStore
    let settingsNavigationStore: SettingsNavigationStore

    var body: some View {
        let clipboardURL = clipboardURLClient.currentURL()

        Group {
            if setupRequired {
                Button {
                    onboardingCoordinator.present()
                } label: {
                    Label(
                        preferencesStore.hasCompletedOnboarding
                            ? "Setup Required…"
                            : "Finish Setup…",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                }
                .accessibilityIdentifier(
                    AccessibilityIdentifier.menuSetupRequired
                )
            } else {
                Button("Open URL from Clipboard") {
                    guard let clipboardURL else {
                        return
                    }

                    pickerCoordinator.handle(clipboardURL)
                }
                .disabled(clipboardURL == nil)
                .accessibilityIdentifier(
                    AccessibilityIdentifier.menuOpenClipboard
                )
            }

            Divider()

            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",", modifiers: .command)
            .accessibilityIdentifier(
                AccessibilityIdentifier.menuSettings
            )

            Menu("More") {
                if !setupRequired {
                    Button("Setup Guide…") {
                        onboardingCoordinator.present()
                    }
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.menuSetupGuide
                    )
                }

                Button("Rules…") {
                    showSettings(
                        pane: .rules
                    )
                }
                .accessibilityIdentifier(
                    AccessibilityIdentifier.menuRules
                )

                Button("About Katabro") {
                    showSettings(
                        pane: .about
                    )
                }
                .accessibilityIdentifier(
                    AccessibilityIdentifier.menuAbout
                )
            }
            .accessibilityIdentifier(
                AccessibilityIdentifier.menuMore
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

    private var setupRequired: Bool {
        !preferencesStore.hasCompletedOnboarding
            || defaultBrowserClient.status != .current
    }

    private func showSettings(
        pane: SettingsPane
    ) {
        settingsNavigationStore.select(pane)
        openSettings()
    }
}
