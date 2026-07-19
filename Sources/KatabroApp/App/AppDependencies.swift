@MainActor
struct AppDependencies {
    let browserDiscovery: any BrowserDiscovering
    let browserLauncher: any BrowserLaunching

    static let live = Self(
        browserDiscovery: WorkspaceBrowserDiscovery(),
        browserLauncher: WorkspaceBrowserLauncher()
    )
}
