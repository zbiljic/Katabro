import SwiftUI

struct SettingsView: View {
    let browserDiscovery: any BrowserDiscovering
    let browserProfileStore: BrowserProfileStore
    let defaultBrowserClient: DefaultBrowserClient
    let loginItemClient: LoginItemClient
    let screenURLCaptureSettings: ScreenURLCaptureSettings
    let screenCaptureClient: ScreenCaptureClient
    let visionURLRecognitionClient: VisionURLRecognitionClient
    let preferencesStore: PreferencesStore
    let routingDecisionLogStore: RoutingDecisionLogStore
    let navigationStore: SettingsNavigationStore
    let configurationFolderClient: ConfigurationFolderClient
    let userScriptBridge: UserScriptBridge
    let allowsSystemProfileConfiguration: Bool
    let onPreviewPicker: () -> Void

    init(
        browserDiscovery: any BrowserDiscovering,
        browserProfileStore: BrowserProfileStore,
        defaultBrowserClient: DefaultBrowserClient,
        loginItemClient: LoginItemClient,
        screenURLCaptureSettings: ScreenURLCaptureSettings,
        screenCaptureClient: ScreenCaptureClient,
        visionURLRecognitionClient: VisionURLRecognitionClient,
        preferencesStore: PreferencesStore,
        routingDecisionLogStore: RoutingDecisionLogStore,
        navigationStore: SettingsNavigationStore = SettingsNavigationStore(),
        configurationFolderClient: ConfigurationFolderClient = .live,
        userScriptBridge: UserScriptBridge,
        allowsSystemProfileConfiguration: Bool = true,
        onPreviewPicker: @escaping () -> Void
    ) {
        self.browserDiscovery = browserDiscovery
        self.browserProfileStore = browserProfileStore
        self.defaultBrowserClient = defaultBrowserClient
        self.loginItemClient = loginItemClient
        self.screenURLCaptureSettings = screenURLCaptureSettings
        self.screenCaptureClient = screenCaptureClient
        self.visionURLRecognitionClient = visionURLRecognitionClient
        self.preferencesStore = preferencesStore
        self.routingDecisionLogStore = routingDecisionLogStore
        self.navigationStore = navigationStore
        self.configurationFolderClient = configurationFolderClient
        self.userScriptBridge = userScriptBridge
        self.allowsSystemProfileConfiguration = allowsSystemProfileConfiguration
        self.onPreviewPicker = onPreviewPicker
    }

    var body: some View {
        @Bindable var navigationStore = navigationStore

        TabView(selection: $navigationStore.selectedPane) {
            GeneralSettingsView(
                defaultBrowserClient: defaultBrowserClient,
                loginItemClient: loginItemClient,
                screenURLCaptureSettings: screenURLCaptureSettings,
                screenCaptureClient: screenCaptureClient,
                visionURLRecognitionClient: visionURLRecognitionClient,
                preferencesStore: preferencesStore,
                configurationFolderClient: configurationFolderClient
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

            PickerSettingsView(
                preferencesStore: preferencesStore,
                onPreviewPicker: onPreviewPicker
            )
            .tabItem {
                Label(
                    SettingsPane.picker.displayName,
                    systemImage: SettingsPane.picker.systemImage
                )
                .accessibilityIdentifier(AccessibilityIdentifier.settingsPickerPane)
            }
            .tag(SettingsPane.picker)

            RulesSettingsView(
                preferencesStore: preferencesStore,
                routingDecisionLogStore: routingDecisionLogStore
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
