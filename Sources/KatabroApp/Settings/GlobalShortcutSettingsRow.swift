import SwiftUI

struct GlobalShortcutSettingsRow: View {
    let settings: GlobalShortcutSettings
    let toggleAccessibilityIdentifier: String
    let fieldAccessibilityIdentifier: String
    let statusAccessibilityIdentifier: String
    let accessibilityHelp: String

    var body: some View {
        LabeledContent("Global shortcut") {
            HStack(spacing: 8) {
                GlobalShortcutField(
                    shortcut: settings.shortcut,
                    isEnabled: settings.isEnabled,
                    accessibilityIdentifier: fieldAccessibilityIdentifier,
                    accessibilityHelp: accessibilityHelp,
                    onChange: settings.setShortcut,
                    onRecordingChanged: settings.setShortcutRecording
                )
                .frame(width: 92)

                Toggle(
                    "Enable global shortcut",
                    isOn: Binding(
                        get: { settings.isEnabled },
                        set: { settings.setEnabled($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel("Enable global shortcut")
                .accessibilityIdentifier(toggleAccessibilityIdentifier)
            }
        }

        if settings.registrationStatus != .disabled {
            Label(
                settings.registrationStatus.description,
                systemImage: statusSymbol
            )
            .font(.callout)
            .foregroundStyle(statusColor)
            .accessibilityIdentifier(statusAccessibilityIdentifier)
        }
    }

    private var statusSymbol: String {
        switch settings.registrationStatus {
        case .registered: "checkmark.circle.fill"
        case .conflict, .failed: "exclamationmark.triangle.fill"
        case .disabled: "circle"
        }
    }

    private var statusColor: Color {
        switch settings.registrationStatus {
        case .conflict, .failed: .red
        case .disabled, .registered: .secondary
        }
    }
}

struct ClipboardURLShortcutSettingsView: View {
    let settings: GlobalShortcutSettings

    var body: some View {
        Section {
            GlobalShortcutSettingsRow(
                settings: settings,
                toggleAccessibilityIdentifier: AccessibilityIdentifier.settingsClipboardURLShortcutToggle,
                fieldAccessibilityIdentifier: AccessibilityIdentifier.settingsClipboardURLShortcutField,
                statusAccessibilityIdentifier: AccessibilityIdentifier.settingsClipboardURLShortcutStatus,
                accessibilityHelp: "Click, then press the global Open URL from Clipboard shortcut. "
                    + "Use at least two modifier keys. Press Escape to cancel."
            )

            Text("Opens the current clipboard URL.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Clipboard URL")
                .accessibilityIdentifier(AccessibilityIdentifier.settingsClipboardURLSection)
        }
    }
}

struct MenuBarShortcutSettingsView: View {
    let settings: GlobalShortcutSettings

    var body: some View {
        Section {
            GlobalShortcutSettingsRow(
                settings: settings,
                toggleAccessibilityIdentifier: AccessibilityIdentifier.settingsMenuBarShortcutToggle,
                fieldAccessibilityIdentifier: AccessibilityIdentifier.settingsMenuBarShortcutField,
                statusAccessibilityIdentifier: AccessibilityIdentifier.settingsMenuBarShortcutStatus,
                accessibilityHelp: "Click, then press the global Show or Hide Katabro Menu shortcut. "
                    + "Use at least two modifier keys. Press Escape to cancel."
            )

            Text("Shows or hides Katabro's menu from any app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Menu Bar")
                .accessibilityIdentifier(AccessibilityIdentifier.settingsMenuBarSection)
        }
    }
}
