import SwiftUI

struct BrowsersSettingsView: View {
    let browserDiscovery: any BrowserDiscovering
    let browserProfileStore: BrowserProfileStore
    let preferencesStore: PreferencesStore
    let userScriptBridge: UserScriptBridge
    let allowsSystemProfileConfiguration: Bool

    var body: some View {
        Form {
            Section {
                BrowserOrderView(
                    browserDiscovery: browserDiscovery,
                    browserProfileStore: browserProfileStore,
                    preferencesStore: preferencesStore,
                    userScriptBridge: userScriptBridge,
                    allowsSystemProfileConfiguration: allowsSystemProfileConfiguration
                )
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(
            AccessibilityIdentifier.settingsBrowsersForm
        )
    }
}
