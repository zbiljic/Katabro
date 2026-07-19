import KatabroCore

@MainActor
struct AppDependencies {
    let browserDiscovery: any BrowserDiscovering
    let browserLauncher: any BrowserLaunching

    static let live = Self(
        browserDiscovery: WorkspaceBrowserDiscovery(
            policy: RoutingPolicy(
                appBundleIdentifier: AppMetadata.bundleIdentifier
            )
        ),
        browserLauncher: WorkspaceBrowserLauncher()
    )
}
