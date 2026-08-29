import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openSettings)
    private var openSettings

    let clipboardURLSnapshotStore: ClipboardURLSnapshotStore
    let clipboardURLShortcutSettings: GlobalShortcutSettings
    let defaultBrowserClient: DefaultBrowserClient
    let onboardingCoordinator: OnboardingWindowCoordinator
    let onOpenClipboardURL: () -> Void
    let screenURLCaptureCoordinator: ScreenURLCaptureCoordinator
    let screenURLCaptureSettings: ScreenURLCaptureSettings
    let preferencesStore: PreferencesStore
    let settingsActionScheduler: any MenuActionScheduling
    let settingsNavigationStore: SettingsNavigationStore

    var body: some View {
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
            Button {
                onOpenClipboardURL()
            } label: {
                Label("Open URL from Clipboard", systemImage: "doc.on.clipboard")
                    .imageScale(.medium)
            }
            .keyboardShortcut(clipboardKeyboardShortcut)
            .accessibilityValue(
                clipboardURLShortcutSettings.registeredDisplayValue
            )
            .accessibilityIdentifier(
                AccessibilityIdentifier.menuOpenClipboard
            )

            if let displayText = clipboardURLSnapshotStore.displayText {
                Text(verbatim: displayText)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 240, alignment: .leading)
                    .accessibilityLabel("Clipboard URL")
                    .accessibilityValue(
                        clipboardURLSnapshotStore.url?.absoluteString ?? displayText
                    )
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.menuClipboardURLPreview
                    )
            }
        }

        if screenURLCaptureSettings.isCaptureEnabled, screenURLCaptureSettings.isCaptureAvailable {
            Button {
                screenURLCaptureCoordinator.capture()
            } label: {
                Label("Capture URLs from Screen", systemImage: "text.viewfinder")
                    .imageScale(.medium)
            }
            .keyboardShortcut(captureKeyboardShortcut)
            .accessibilityValue(
                screenURLCaptureSettings.globalShortcutSettings.registeredDisplayValue
            )
            .accessibilityIdentifier(AccessibilityIdentifier.menuCaptureScreenURLs)
        }

        Divider()

        Button("Settings…") {
            presentSettings()
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

    private var setupRequired: Bool {
        !preferencesStore.hasCompletedOnboarding
            || defaultBrowserClient.status != .current
    }

    private var clipboardKeyboardShortcut: KeyboardShortcut? {
        guard clipboardURLShortcutSettings.registrationStatus == .registered else {
            return nil
        }
        return clipboardURLShortcutSettings.shortcut.keyboardShortcut
    }

    private var captureKeyboardShortcut: KeyboardShortcut? {
        guard
            screenURLCaptureSettings.isCaptureEnabled,
            screenURLCaptureSettings.isCaptureAvailable,
            screenURLCaptureSettings.isEnabled,
            screenURLCaptureSettings.registrationStatus == .registered
        else {
            return nil
        }
        return screenURLCaptureSettings.shortcut.keyboardShortcut
    }

    private func showSettings(
        pane: SettingsPane
    ) {
        settingsNavigationStore.select(pane)
        presentSettings()
    }

    @MainActor
    private func presentSettings() {
        let openSettings = openSettings
        settingsActionScheduler.schedule {
            openSettings()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
