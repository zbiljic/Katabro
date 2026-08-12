import SwiftUI

struct SettingsView: View {
    let browserDiscovery: any BrowserDiscovering
    let defaultBrowserClient: DefaultBrowserClient
    let loginItemClient: LoginItemClient
    let preferencesStore: PreferencesStore

    @State private var selectedPane: SettingsPane

    init(
        browserDiscovery: any BrowserDiscovering,
        defaultBrowserClient: DefaultBrowserClient,
        loginItemClient: LoginItemClient,
        preferencesStore: PreferencesStore,
        initialPane: SettingsPane = .general
    ) {
        self.browserDiscovery = browserDiscovery
        self.defaultBrowserClient = defaultBrowserClient
        self.loginItemClient = loginItemClient
        self.preferencesStore = preferencesStore
        _selectedPane = State(initialValue: initialPane)
    }

    var body: some View {
        TabView(selection: $selectedPane) {
            GeneralSettingsView(
                defaultBrowserClient: defaultBrowserClient,
                loginItemClient: loginItemClient,
                preferencesStore: preferencesStore
            )
            .tabItem {
                Label(
                    SettingsPane.general.displayName,
                    systemImage: SettingsPane.general.systemImage
                )
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsGeneralPane
                )
            }
            .tag(SettingsPane.general)

            BrowsersSettingsView(
                browserDiscovery: browserDiscovery,
                preferencesStore: preferencesStore
            )
            .tabItem {
                Label(
                    SettingsPane.browsers.displayName,
                    systemImage: SettingsPane.browsers.systemImage
                )
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsBrowsersPane
                )
            }
            .tag(SettingsPane.browsers)
        }
        .frame(
            minWidth: 560,
            minHeight: 560
        )
    }
}
