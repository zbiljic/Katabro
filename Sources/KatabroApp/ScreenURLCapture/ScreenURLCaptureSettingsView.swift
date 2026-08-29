import SwiftUI

struct ScreenURLCaptureSettingsView: View {
    let settings: ScreenURLCaptureSettings
    let screenCaptureClient: ScreenCaptureClient
    let visionURLRecognitionClient: VisionURLRecognitionClient

    var body: some View {
        Section {
            Toggle(
                "Enable Screen URL Capture",
                isOn: Binding(
                    get: { settings.isCaptureEnabled },
                    set: { settings.setCaptureEnabled($0) }
                )
            )
            .disabled(!isCaptureAvailable)
            .accessibilityIdentifier(AccessibilityIdentifier.settingsScreenURLCaptureToggle)

            if isCaptureAvailable, settings.isCaptureEnabled {
                GlobalShortcutSettingsRow(
                    settings: settings.globalShortcutSettings,
                    toggleAccessibilityIdentifier: AccessibilityIdentifier.settingsScreenURLShortcutToggle,
                    fieldAccessibilityIdentifier: AccessibilityIdentifier.settingsScreenURLShortcutField,
                    statusAccessibilityIdentifier: AccessibilityIdentifier.settingsScreenURLShortcutStatus,
                    accessibilityHelp: "Click, then press the global Screen URL Capture shortcut. "
                        + "Use at least two modifier keys. Press Escape to cancel."
                )

                permissionStatus

                Text("Uses Apple Vision on this Mac. Screenshots, recognized text, and detected URLs are not saved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !isCaptureAvailable {
                Text("On-device text recognition is unavailable on this Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityIdentifier.settingsScreenURLCaptureUnavailable)
            }
        } header: {
            Text("Screen URL Capture")
                .accessibilityIdentifier(AccessibilityIdentifier.settingsScreenURLCaptureSection)
        }
    }

    @ViewBuilder private var permissionStatus: some View {
        if settings.screenCaptureAuthorization == .authorized {
            LabeledContent("Screen Recording") {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Screen Recording access is enabled.")
            .accessibilityIdentifier(AccessibilityIdentifier.settingsScreenURLPermissionGranted)
        } else {
            LabeledContent("Screen Recording") {
                Text("Required")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Screen Recording access is required to capture a display.")
            .accessibilityIdentifier(AccessibilityIdentifier.settingsScreenURLPermissionStatus)

            Text(
                "Katabro needs access only when you capture URLs. "
                    + "Allow it in Privacy & Security, then capture again."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            HStack {
                Button("Request Access…") {
                    settings.requestScreenCaptureAuthorization()
                }
                .accessibilityIdentifier(AccessibilityIdentifier.settingsScreenURLRequestAccess)

                Button("Open Screen Recording Settings…") {
                    screenCaptureClient.openSystemSettings()
                }
                .accessibilityIdentifier(AccessibilityIdentifier.settingsScreenURLOpenSystemSettings)
            }
        }
    }

    private var isCaptureAvailable: Bool {
        settings.isCaptureAvailable && visionURLRecognitionClient.isAvailable()
    }
}
