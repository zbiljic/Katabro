import KatabroCore

@MainActor
struct AppDependencies {
    let browserDiscovery: any BrowserDiscovering
    let browserLauncher: any BrowserLaunching
    let errorPresenter: any RoutingErrorPresenting
    let preferencesStore: PreferencesStore

    static let live = Self(
        browserDiscovery: WorkspaceBrowserDiscovery(
            policy: RoutingPolicy(
                appBundleIdentifier: AppMetadata.bundleIdentifier
            )
        ),
        browserLauncher: WorkspaceBrowserLauncher(),
        errorPresenter: AlertRoutingErrorPresenter(),
        preferencesStore: .live()
    )
}
