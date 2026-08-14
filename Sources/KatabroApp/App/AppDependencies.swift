import KatabroCore

@MainActor
struct AppDependencies {
    let browserDiscovery: any BrowserDiscovering
    let browserLauncher: any BrowserLaunching
    let defaultBrowserClient: DefaultBrowserClient
    let errorPresenter: any RoutingErrorPresenting
    let loginItemClient: LoginItemClient
    var browserProfileStore = BrowserProfileStore()
    let preferencesStore: PreferencesStore
    var userScriptBridge = UserScriptBridge(
        initialInstallationState: .missing
    )
    var allowsSystemProfileConfiguration = true

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
            browserProfileStore: .live(),
            preferencesStore: .live(),
            userScriptBridge: userScriptBridge
        )
    }()
}
