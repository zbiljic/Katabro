import SwiftUI

struct BrowsersSettingsView: View {
    let browserDiscovery: any BrowserDiscovering
    let preferencesStore: PreferencesStore

    var body: some View {
        Form {
            Section {
                BrowserOrderView(
                    browserDiscovery: browserDiscovery,
                    preferencesStore: preferencesStore
                )
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(
            AccessibilityIdentifier.settingsBrowsersForm
        )
    }
}
