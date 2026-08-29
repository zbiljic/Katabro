import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let clipboardShortcutEnabledKey = "clipboardURL.globalShortcutEnabled.v1"
    static let clipboardShortcutKey = "clipboardURL.globalShortcut.v1"

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

    lazy var screenURLCaptureCoordinator = ScreenURLCaptureCoordinator(
        dependencies: dependencies,
        pickerCoordinator: pickerCoordinator
    )

    lazy var screenURLCaptureSettings = ScreenURLCaptureSettings(
        defaults: dependencies.globalShortcutDefaults,
        registrar: dependencies.globalHotKeyRegistrar,
        screenCaptureClient: dependencies.screenCaptureClient,
        isCaptureAvailable: dependencies.visionURLRecognitionClient.isAvailable(),
        onCaptureDisabled: { [weak self] in
            self?.screenURLCaptureCoordinator.cancel()
        },
        onShortcut: { [weak self] in
            self?.screenURLCaptureCoordinator.capture()
        }
    )

    lazy var clipboardURLSnapshotStore = ClipboardURLSnapshotStore(
        clipboardURLClient: dependencies.clipboardURLClient
    )

    lazy var clipboardURLShortcutSettings = GlobalShortcutSettings(
        configuration: .init(
            identifier: .openURLFromClipboard,
            enabledKey: Self.clipboardShortcutEnabledKey,
            shortcutKey: Self.clipboardShortcutKey,
            defaultShortcut: .openURLFromClipboardDefault,
            registrationAllowed: true
        ),
        defaults: dependencies.globalShortcutDefaults,
        registrar: dependencies.globalHotKeyRegistrar
    ) { [weak self] in
        self?.openClipboardURL()
    }

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
        screenURLCaptureSettings.start()
        clipboardURLShortcutSettings.start()
        onboardingCoordinator.presentIfNeeded()
    }

    func applicationWillTerminate(
        _: Notification
    ) {
        clipboardURLSnapshotStore.stopMonitoring()
        screenURLCaptureSettings.unregister()
        clipboardURLShortcutSettings.unregister()
        dependencies.routingDecisionLogStore.clear()
    }

    func applicationDidBecomeActive(
        _: Notification
    ) {
        dependencies.defaultBrowserClient.refresh()
        dependencies.loginItemClient.refresh()
        dependencies.preferencesStore.refreshActiveSync()
        screenURLCaptureSettings.refreshScreenCaptureAuthorization()
    }

    func application(
        _: NSApplication,
        open urls: [URL]
    ) {
        pickerCoordinator.handle(urls)
    }

    func openClipboardURL() {
        clipboardURLSnapshotStore.refresh()
        pickerCoordinator.openClipboardURL(clipboardURLSnapshotStore.url)
    }
}
