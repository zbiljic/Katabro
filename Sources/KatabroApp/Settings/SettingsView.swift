import SwiftUI

struct SettingsView: View {
    let browserDiscovery: any BrowserDiscovering
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

            Section {
                BrowserOrderView(
                    browserDiscovery: browserDiscovery,
                    preferencesStore: preferencesStore
                )
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(
            AccessibilityIdentifier.settingsForm
        )
        .frame(
            minWidth: 560,
            minHeight: 560
        )
        .task {
            defaultBrowserClient.refresh()
            loginItemClient.refresh()
        }
    }
}
