import KatabroCore

@MainActor
struct AppDependencies {
    let browserDiscovery: any BrowserDiscovering
    let browserLauncher: any BrowserLaunching
    let defaultBrowserClient: DefaultBrowserClient
    let errorPresenter: any RoutingErrorPresenting
    let loginItemClient: LoginItemClient
    let preferencesStore: PreferencesStore

    static let live = Self(
        browserDiscovery: WorkspaceBrowserDiscovery(
            policy: RoutingPolicy(
                appBundleIdentifier: AppMetadata.bundleIdentifier
            )
        ),
        browserLauncher: WorkspaceBrowserLauncher(),
        defaultBrowserClient: .live(),
        errorPresenter: AlertRoutingErrorPresenter(),
        loginItemClient: .live(),
        preferencesStore: .live()
    )
}
