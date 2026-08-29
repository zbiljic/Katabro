import KatabroCore

@MainActor
struct AppDependencies {
    let browserDiscovery: any BrowserDiscovering
    let browserLauncher: any BrowserLaunching
    let defaultBrowserClient: DefaultBrowserClient
    let errorPresenter: any RoutingErrorPresenting
    let loginItemClient: LoginItemClient
    let routingDecisionClient: RoutingDecisionClient
    let routingDecisionLogStore: RoutingDecisionLogStore
    var browserProfileStore = BrowserProfileStore()
    let preferencesStore: PreferencesStore
    var clipboardURLClient = ClipboardURLClient.live
    var settingsNavigationStore = SettingsNavigationStore()
    var configurationFolderClient = ConfigurationFolderClient.live
    var userScriptBridge = UserScriptBridge(
        initialInstallationState: .missing
    )
    var allowsSystemProfileConfiguration = true
    var screenCaptureClient = ScreenCaptureClient.inert
    var visionURLRecognitionClient = VisionURLRecognitionClient.unavailable

    static let live: Self = {
        let userScriptBridge = UserScriptBridge()

        return Self(
            browserDiscovery: WorkspaceBrowserDiscovery(
                policy: RoutingPolicy(
                    appBundleIdentifier: AppMetadata.bundleIdentifier
                )
            ),
            browserLauncher: WorkspaceBrowserLauncher(
                userScriptBridge: userScriptBridge
            ),
            defaultBrowserClient: .live(),
            errorPresenter: AlertRoutingErrorPresenter(),
            loginItemClient: .live(),
            routingDecisionClient: .exactHostRules,
            routingDecisionLogStore: RoutingDecisionLogStore(),
            browserProfileStore: .live(),
            preferencesStore: .live(),
            userScriptBridge: userScriptBridge,
            screenCaptureClient: .live,
            visionURLRecognitionClient: .live
        )
    }()
}
