import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openSettings)
    private var openSettings

    let clipboardURLSnapshotStore: ClipboardURLSnapshotStore
    let defaultBrowserClient: DefaultBrowserClient
    let onboardingCoordinator: OnboardingWindowCoordinator
    let pickerCoordinator: BrowserPickerCoordinator
    let screenURLCaptureCoordinator: ScreenURLCaptureCoordinator
    let screenURLCaptureSettings: ScreenURLCaptureSettings
    let preferencesStore: PreferencesStore
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
                pickerCoordinator.openClipboardURL(
                    clipboardURLSnapshotStore.url
                )
            } label: {
                Label("Open URL from Clipboard", systemImage: "doc.on.clipboard")
                    .imageScale(.medium)
            }
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
                screenURLCaptureSettings.isEnabled
                    ? screenURLCaptureSettings.shortcut.displayValue
                    : ""
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

    private var captureKeyboardShortcut: KeyboardShortcut? {
        let shortcut = screenURLCaptureSettings.shortcut
        guard
            screenURLCaptureSettings.isCaptureEnabled,
            screenURLCaptureSettings.isCaptureAvailable,
            screenURLCaptureSettings.isEnabled,
            shortcut.displayKey.count == 1,
            let character = shortcut.displayKey.lowercased().first
        else {
            return nil
        }

        var modifiers: EventModifiers = []
        if shortcut.modifiers.contains(.command) {
            modifiers.insert(.command)
        }
        if shortcut.modifiers.contains(.option) {
            modifiers.insert(.option)
        }
        if shortcut.modifiers.contains(.control) {
            modifiers.insert(.control)
        }
        if shortcut.modifiers.contains(.shift) {
            modifiers.insert(.shift)
        }
        return KeyboardShortcut(KeyEquivalent(character), modifiers: modifiers)
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
        RunLoop.main.perform(inModes: [.default]) {
            MainActor.assumeIsolated {
                openSettings()
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }
}
