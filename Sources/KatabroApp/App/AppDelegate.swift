import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let dependencies: AppDependencies

    lazy var pickerCoordinator = BrowserPickerCoordinator(
        dependencies: dependencies
    )

    lazy var onboardingCoordinator = OnboardingWindowCoordinator(
        defaultBrowserClient: dependencies.defaultBrowserClient,
        preferencesStore: dependencies.preferencesStore
    )

    override convenience init() {
        self.init(
            dependencies: .live
        )
    }

    init(
        dependencies: AppDependencies
    ) {
        self.dependencies = dependencies
        super.init()
    }

    func applicationDidFinishLaunching(
        _: Notification
    ) {
        onboardingCoordinator.presentIfNeeded()
    }

    func applicationDidBecomeActive(
        _: Notification
    ) {
        dependencies.defaultBrowserClient.refresh()
        dependencies.loginItemClient.refresh()
    }

    func application(
        _: NSApplication,
        open urls: [URL]
    ) {
        pickerCoordinator.handle(urls)
    }
}
