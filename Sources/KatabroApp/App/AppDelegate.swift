import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let dependencies: AppDependencies

    #if DEBUG
        let developmentUIConfiguration: DevelopmentUIConfiguration?

        private lazy var developmentUIWindowCoordinator = developmentUIConfiguration.map {
            DevelopmentUIWindowCoordinator(
                configuration: $0,
                dependencies: dependencies,
                clipboardURLSnapshotStore: clipboardURLSnapshotStore,
                onboardingCoordinator: onboardingCoordinator,
                pickerCoordinator: pickerCoordinator
            )
        }
    #endif

    lazy var pickerCoordinator = BrowserPickerCoordinator(
        dependencies: dependencies
    )

    lazy var clipboardURLSnapshotStore = ClipboardURLSnapshotStore(
        clipboardURLClient: dependencies.clipboardURLClient
    )

    lazy var onboardingCoordinator = OnboardingWindowCoordinator(
        defaultBrowserClient: dependencies.defaultBrowserClient,
        preferencesStore: dependencies.preferencesStore
    )

    override convenience init() {
        #if DEBUG
            let configuration = DevelopmentUIConfiguration.current()
            self.init(
                dependencies: configuration.map {
                    DevelopmentUIFixtures.dependencies(
                        for: $0.state,
                        preferencesSuite: $0.preferencesSuite,
                        resetsPreferences: $0.resetsPreferences
                    )
                } ?? .live,
                developmentUIConfiguration: configuration
            )
        #else
            self.init(
                dependencies: .live
            )
        #endif
    }

    init(
        dependencies: AppDependencies
    ) {
        self.dependencies = dependencies
        #if DEBUG
            developmentUIConfiguration = nil
        #endif
        super.init()
    }

    #if DEBUG
        init(
            dependencies: AppDependencies,
            developmentUIConfiguration: DevelopmentUIConfiguration?
        ) {
            self.dependencies = dependencies
            self.developmentUIConfiguration = developmentUIConfiguration
            super.init()
        }
    #endif

    func applicationDidFinishLaunching(
        _: Notification
    ) {
        clipboardURLSnapshotStore.startMonitoring()

        #if DEBUG
            if let developmentUIWindowCoordinator {
                developmentUIWindowCoordinator.present()
                return
            }
        #endif
        onboardingCoordinator.presentIfNeeded()
    }

    func applicationWillTerminate(
        _: Notification
    ) {
        clipboardURLSnapshotStore.stopMonitoring()
    }

    func applicationDidBecomeActive(
        _: Notification
    ) {
        dependencies.defaultBrowserClient.refresh()
        dependencies.loginItemClient.refresh()
        dependencies.preferencesStore.refreshActiveSync()
    }

    func application(
        _: NSApplication,
        open urls: [URL]
    ) {
        pickerCoordinator.handle(urls)
    }
}
