import SwiftUI

struct SettingsView: View {
    let browserDiscovery: any BrowserDiscovering
    let browserProfileStore: BrowserProfileStore
    let defaultBrowserClient: DefaultBrowserClient
    let loginItemClient: LoginItemClient
    let preferencesStore: PreferencesStore
    let userScriptBridge: UserScriptBridge
    let allowsSystemProfileConfiguration: Bool

    @State private var selectedPane: SettingsPane

    init(
        browserDiscovery: any BrowserDiscovering,
        browserProfileStore: BrowserProfileStore,
        defaultBrowserClient: DefaultBrowserClient,
        loginItemClient: LoginItemClient,
        preferencesStore: PreferencesStore,
        userScriptBridge: UserScriptBridge,
        allowsSystemProfileConfiguration: Bool = true,
        initialPane: SettingsPane = .general
    ) {
        self.browserDiscovery = browserDiscovery
        self.browserProfileStore = browserProfileStore
        self.defaultBrowserClient = defaultBrowserClient
        self.loginItemClient = loginItemClient
        self.preferencesStore = preferencesStore
        self.userScriptBridge = userScriptBridge
        self.allowsSystemProfileConfiguration = allowsSystemProfileConfiguration
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
                browserProfileStore: browserProfileStore,
                preferencesStore: preferencesStore,
                userScriptBridge: userScriptBridge,
                allowsSystemProfileConfiguration: allowsSystemProfileConfiguration
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

            RulesSettingsView(
                preferencesStore: preferencesStore
            )
            .tabItem {
                Label(
                    SettingsPane.rules.displayName,
                    systemImage: SettingsPane.rules.systemImage
                )
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsRulesPane
                )
            }
            .tag(SettingsPane.rules)

            AboutSettingsView()
                .tabItem {
                    Label(
                        SettingsPane.about.displayName,
                        systemImage: SettingsPane.about.systemImage
                    )
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.settingsAboutPane
                    )
                }
                .tag(SettingsPane.about)
        }
        .frame(
            minWidth: 560,
            minHeight: 560
        )
    }
}
