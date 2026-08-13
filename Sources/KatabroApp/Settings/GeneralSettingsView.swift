import SwiftUI

struct GeneralSettingsView: View {
    let defaultBrowserClient: DefaultBrowserClient
    let loginItemClient: LoginItemClient
    let preferencesStore: PreferencesStore

    var body: some View {
        Form {
            Section("Default Browser") {
                LabeledContent("Status") {
                    Text(defaultBrowserClient.statusDescription)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(
                            AccessibilityIdentifier.settingsDefaultBrowserStatus
                        )
                }

                Button("Use Katabro as Default Browser…") {
                    Task {
                        await defaultBrowserClient.requestDefaultBrowser()
                    }
                }
                .disabled(defaultBrowserClient.isRequesting)
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsDefaultBrowserAction
                )

                if let lastError = defaultBrowserClient.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .accessibilityIdentifier(
                            AccessibilityIdentifier.settingsDefaultBrowserError
                        )
                }
            }

            Section("Startup") {
                Toggle(
                    "Open Katabro at login",
                    isOn: Binding(
                        get: {
                            loginItemClient.isEnabled
                        },
                        set: { enabled in
                            loginItemClient.update(
                                enabled: enabled
                            )
                        }
                    )
                )
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsLoginItemToggle
                )

                Text(loginItemClient.statusDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.settingsLoginItemStatus
                    )

                if let lastError = loginItemClient.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .accessibilityIdentifier(
                            AccessibilityIdentifier.settingsLoginItemError
                        )
                }
            }

            Section("iCloud") {
                LabeledContent("Browser Settings") {
                    Text(iCloudStatusDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel(iCloudStatusDescription)
                        .accessibilityIdentifier(
                            AccessibilityIdentifier.settingsICloudStatus
                        )
                }
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(
            AccessibilityIdentifier.settingsGeneralForm
        )
        .task {
            defaultBrowserClient.refresh()
            loginItemClient.refresh()
        }
    }

    private var iCloudStatusDescription: String {
        switch preferencesStore.iCloudSyncStatus {
        case .available:
            "Browser order and picker shortcuts sync through iCloud across Macs using the same Apple Account."
        case .localOnly:
            "Browser order and picker shortcuts stay on this Mac because iCloud sync is unavailable for this build."
        case .invalidCloudValue:
            "Some browser settings stay on this Mac because the saved iCloud settings could not be read."
        }
    }
}
