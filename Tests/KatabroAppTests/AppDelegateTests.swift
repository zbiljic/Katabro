import AppKit
@testable import Katabro
import KatabroCore
import Testing

// swiftlint:disable multiline_arguments type_body_length

@MainActor
@Suite("Application lifecycle")
struct AppDelegateTests {
    @Test("onboarding launches only before completion")
    func evaluatesOnboardingLaunchState() {
        #expect(
            OnboardingLaunchPolicy.shouldPresent(
                hasCompletedOnboarding: false
            )
        )
        #expect(
            !OnboardingLaunchPolicy.shouldPresent(
                hasCompletedOnboarding: true
            )
        )
    }

    @Test("becoming active refreshes externally changed system status")
    func refreshesSystemStatus() {
        let state = AppLifecycleState()
        let defaultBrowserClient = DefaultBrowserClient(
            appBundleIdentifier: "com.example.Katabro",
            currentHandler: { scheme in
                state.browserHandlers[scheme]
            },
            requestHandler: { _ in }
        )
        let loginItemClient = LoginItemClient(
            statusProvider: {
                state.loginItemStatus
            },
            updateHandler: { _ in }
        )
        let delegate = AppDelegate(
            dependencies: AppDependencies(
                browserDiscovery: BrowserDiscoveryFake(),
                browserLauncher: BrowserLauncherFake(),
                defaultBrowserClient: defaultBrowserClient,
                errorPresenter: RoutingErrorPresenterFake(),
                loginItemClient: loginItemClient,
                routingDecisionClient: .exactHostRules,
                routingDecisionLogStore: RoutingDecisionLogStore(),
                preferencesStore: PreferencesStore()
            )
        )

        #expect(defaultBrowserClient.status == .notCurrent)
        #expect(loginItemClient.status == .disabled)

        state.browserHandlers["http"] = "com.example.Katabro"
        state.browserHandlers["https"] = "com.example.Katabro"
        state.loginItemStatus = .enabled
        delegate.applicationDidBecomeActive(
            Notification(
                name: NSApplication.didBecomeActiveNotification
            )
        )

        #expect(defaultBrowserClient.status == .current)
        #expect(loginItemClient.status == .enabled)
    }

    @Test("becoming active refreshes the selected Folder transport")
    func refreshesFolderTransport() {
        var refreshCount = 0
        let snapshot = BrowserSettingsSnapshot(
            browserOrder: [],
            pickerShortcuts: [:],
            exactHostRoutingRules: []
        )
        // swiftlint:disable trailing_closure
        let client = FilePreferencesClient(
            injectedRead: {
                refreshCount += 1
                return .snapshot(snapshot, bytes: (try? snapshot.encodedData()) ?? Data())
            }
        )
        // swiftlint:enable trailing_closure
        let store = PreferencesStore(syncMethod: .thisMac)
        #expect(store.configureFolderSync(client: client, displayName: "Fixture"))
        refreshCount = 0
        let delegate = AppDelegate(
            dependencies: AppDependencies(
                browserDiscovery: BrowserDiscoveryFake(),
                browserLauncher: BrowserLauncherFake(),
                defaultBrowserClient: .development(status: .notCurrent),
                errorPresenter: RoutingErrorPresenterFake(),
                loginItemClient: .development(status: .disabled),
                routingDecisionClient: .exactHostRules,
                routingDecisionLogStore: RoutingDecisionLogStore(),
                preferencesStore: store
            )
        )

        delegate.applicationDidBecomeActive(
            Notification(name: NSApplication.didBecomeActiveNotification)
        )
        #expect(refreshCount == 1)
    }

    @Test("termination clears recent routes")
    func clearsRecentRoutesOnTermination() throws {
        let routingDecisionLogStore = RoutingDecisionLogStore()
        try routingDecisionLogStore.receive(
            RoutingRequest(
                destination: IncomingURL("https://example.com/private"),
                source: .system
            )
        )
        let delegate = AppDelegate(
            dependencies: AppDependencies(
                browserDiscovery: BrowserDiscoveryFake(),
                browserLauncher: BrowserLauncherFake(),
                defaultBrowserClient: .development(status: .notCurrent),
                errorPresenter: RoutingErrorPresenterFake(),
                loginItemClient: .development(status: .disabled),
                routingDecisionClient: .exactHostRules,
                routingDecisionLogStore: routingDecisionLogStore,
                preferencesStore: PreferencesStore(),
                clipboardURLClient: .development(url: nil)
            )
        )

        #expect(routingDecisionLogStore.entries.count == 1)
        delegate.applicationWillTerminate(
            Notification(name: NSApplication.willTerminateNotification)
        )

        #expect(routingDecisionLogStore.entries.isEmpty)
    }

    @Test("termination unregisters all global commands exactly once")
    func terminationUnregistersShortcuts() {
        let registrar = AppDelegateRegistrarFake()
        let defaults = isolatedShortcutDefaults()
        let center = NotificationCenter()
        let menu = NSMenu()
        let menuActions = ShortcutCallbackState()
        let menuPresentationState = MenuBarPresentationState(
            notificationCenter: center
        ) { menuActions.eventTime }
        menuPresentationState.connect(
            menu: menu,
            open: { menuActions.menuOpenCount += 1 },
            close: { menuActions.menuCloseCount += 1 }
        )
        let delegate = AppDelegate(
            dependencies: AppDependencies(
                browserDiscovery: BrowserDiscoveryFake(), browserLauncher: BrowserLauncherFake(),
                defaultBrowserClient: .development(status: .notCurrent), errorPresenter: RoutingErrorPresenterFake(),
                loginItemClient: .development(status: .disabled), routingDecisionClient: .exactHostRules,
                routingDecisionLogStore: RoutingDecisionLogStore(), preferencesStore: PreferencesStore(),
                globalHotKeyRegistrar: registrar,
                globalShortcutDefaults: defaults
            ),
            menuBarPresentationState: menuPresentationState
        )
        delegate.screenURLCaptureSettings.setEnabled(true)
        delegate.clipboardURLShortcutSettings.setEnabled(true)
        delegate.menuBarShortcutSettings.setEnabled(true)
        menuActions.eventTime = 10
        center.post(name: NSMenu.didBeginTrackingNotification, object: menu)
        let beforeTermination = registrar.unregisterCalls
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        #expect(
            registrar.unregisterCalls.dropFirst(beforeTermination.count) == [
                .screenURLCapture,
                .openURLFromClipboard,
                .showKatabroMenu,
            ]
        )
        menuActions.eventTime = 20
        center.post(name: NSMenu.didEndTrackingNotification, object: menu)
        menuPresentationState.toggle(eventTime: 15)
        #expect(menuPresentationState.isPresented)
        #expect(menuActions.menuOpenCount == 0)
        #expect(menuActions.menuCloseCount == 0)
    }

    @Test("production-equivalent launch starts global commands in stable order")
    func launchStartsShortcutsInOrder() {
        let registrar = AppDelegateRegistrarFake()
        let defaults = isolatedShortcutDefaults()
        defaults.set(true, forKey: ScreenURLCaptureSettings.enabledKey)
        defaults.set(true, forKey: AppDelegate.clipboardShortcutEnabledKey)
        defaults.set(true, forKey: AppDelegate.menuBarShortcutEnabledKey)
        let delegate = AppDelegate(
            dependencies: AppDependencies(
                browserDiscovery: BrowserDiscoveryFake(), browserLauncher: BrowserLauncherFake(),
                defaultBrowserClient: .development(status: .notCurrent), errorPresenter: RoutingErrorPresenterFake(),
                loginItemClient: .development(status: .disabled), routingDecisionClient: .exactHostRules,
                routingDecisionLogStore: RoutingDecisionLogStore(), preferencesStore: PreferencesStore(),
                visionURLRecognitionClient: VisionURLRecognitionClient(
                    isAvailable: { true },
                    recognizeURLs: { _ in [] }
                ),
                globalHotKeyRegistrar: registrar, globalShortcutDefaults: defaults
            )
        )

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        #expect(registrar.registerCalls == [
            .screenURLCapture,
            .openURLFromClipboard,
            .showKatabroMenu,
        ])
    }

    @Test("clipboard shortcut refreshes the current generation and routes exactly once")
    func clipboardShortcutRefreshesAndRoutes() async throws {
        let state = ClipboardCommandState()
        let discovery = BrowserDiscoveryFake(browsers: [makeBrowser()])
        let registrar = AppDelegateRegistrarFake()
        let dependencies = AppDependencies(
            browserDiscovery: discovery,
            browserLauncher: BrowserLauncherFake(),
            defaultBrowserClient: .development(status: .current),
            errorPresenter: RoutingErrorPresenterFake(),
            loginItemClient: .development(status: .disabled),
            routingDecisionClient: .exactHostRules,
            routingDecisionLogStore: RoutingDecisionLogStore(),
            preferencesStore: PreferencesStore(),
            clipboardURLClient: ClipboardURLClient(
                currentURLHandler: {
                    state.readCount += 1
                    return state.currentURL
                },
                changeCountHandler: { state.changeCount }
            ),
            globalHotKeyRegistrar: registrar,
            globalShortcutDefaults: isolatedShortcutDefaults()
        )
        let delegate = AppDelegate(dependencies: dependencies)
        delegate.clipboardURLSnapshotStore.refresh()
        let freshURL = try #require(URL(string: "https://fresh.example/path"))
        state.currentURL = freshURL
        state.changeCount += 1
        delegate.pickerCoordinator = BrowserPickerCoordinator(
            dependencies: dependencies,
            menuActionScheduler: ImmediateMenuActionScheduler()
        ) { _, _, _, _ in BrowserPickerPresentationFake() }

        delegate.clipboardURLShortcutSettings.setEnabled(true)
        registrar.fire(.openURLFromClipboard)
        await delegate.pickerCoordinator.waitForPendingOperations()

        #expect(state.readCount == 2)
        #expect(delegate.clipboardURLSnapshotStore.url == freshURL)
        #expect(try discovery.destinations == [IncomingURL(freshURL)])
    }

    @Test("empty clipboard command uses the existing picker error path")
    func emptyClipboardUsesExistingError() {
        let errorPresenter = RoutingErrorPresenterFake()
        let dependencies = AppDependencies(
            browserDiscovery: BrowserDiscoveryFake(),
            browserLauncher: BrowserLauncherFake(),
            defaultBrowserClient: .development(status: .current),
            errorPresenter: errorPresenter,
            loginItemClient: .development(status: .disabled),
            routingDecisionClient: .exactHostRules,
            routingDecisionLogStore: RoutingDecisionLogStore(),
            preferencesStore: PreferencesStore(),
            clipboardURLClient: .development(url: nil),
            globalShortcutDefaults: isolatedShortcutDefaults()
        )
        let delegate = AppDelegate(dependencies: dependencies)
        delegate.pickerCoordinator = BrowserPickerCoordinator(
            dependencies: dependencies,
            menuActionScheduler: ImmediateMenuActionScheduler()
        )

        delegate.openClipboardURL()

        #expect(errorPresenter.presentedErrors == ["noRoutableURL"])
    }

    @Test("global shortcut callbacks do not cross-trigger")
    func globalShortcutCallbacksAreIsolated() async throws { // swiftlint:disable:this function_body_length
        let state = ShortcutCallbackState()
        let menu = NSMenu()
        let menuNotificationCenter = NotificationCenter()
        let connectedMenuPresentationState = MenuBarPresentationState(
            notificationCenter: menuNotificationCenter
        ) { state.eventTime }
        connectedMenuPresentationState.connect(
            menu: menu,
            open: {
                state.menuOpenCount += 1
            },
            close: {
                state.menuCloseCount += 1
            }
        )
        let context = try #require(CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try #require(context.makeImage())
        let clipboardURL = try #require(URL(string: "https://clipboard.example/path"))
        let discovery = BrowserDiscoveryFake(browsers: [makeBrowser()])
        let registrar = AppDelegateRegistrarFake()
        let screenCaptureClient = ScreenCaptureClient(
            authorizationStatus: { .authorized },
            requestAuthorization: { false },
            capture: {
                state.captureCount += 1
                return image
            }
        )
        let recognitionClient = VisionURLRecognitionClient(
            isAvailable: { true },
            recognizeURLs: { _ in [] }
        )
        let dependencies = AppDependencies(
            browserDiscovery: discovery,
            browserLauncher: BrowserLauncherFake(),
            defaultBrowserClient: .development(status: .current),
            errorPresenter: RoutingErrorPresenterFake(),
            loginItemClient: .development(status: .disabled),
            routingDecisionClient: .exactHostRules,
            routingDecisionLogStore: RoutingDecisionLogStore(),
            preferencesStore: PreferencesStore(),
            clipboardURLClient: ClipboardURLClient {
                state.clipboardReadCount += 1
                return clipboardURL
            },
            screenCaptureClient: screenCaptureClient,
            visionURLRecognitionClient: recognitionClient,
            globalHotKeyRegistrar: registrar,
            globalShortcutDefaults: isolatedShortcutDefaults()
        )
        let delegate = AppDelegate(
            dependencies: dependencies,
            menuBarPresentationState: connectedMenuPresentationState
        )
        delegate.pickerCoordinator = BrowserPickerCoordinator(
            dependencies: dependencies,
            menuActionScheduler: ImmediateMenuActionScheduler()
        ) { _, _, _, _ in BrowserPickerPresentationFake() }
        delegate.screenURLCaptureCoordinator = ScreenURLCaptureCoordinator(
            captureClient: screenCaptureClient,
            recognitionClient: recognitionClient,
            route: { _ in state.screenRouteCount += 1 },
            panelBuilder: { _, _, _ in AppDelegateScreenPanelFake() }
        )
        delegate.screenURLCaptureSettings.setEnabled(true)
        delegate.clipboardURLShortcutSettings.setEnabled(true)
        delegate.menuBarShortcutSettings.setEnabled(true)

        registrar.fire(.screenURLCapture)
        await delegate.screenURLCaptureCoordinator.waitForPendingOperations()

        #expect(state.captureCount == 1)
        #expect(state.clipboardReadCount == 0)
        #expect(discovery.destinations.isEmpty)
        #expect(state.screenRouteCount == 0)
        #expect(state.menuOpenCount == 0)
        #expect(state.menuCloseCount == 0)

        registrar.fire(.openURLFromClipboard)
        await delegate.pickerCoordinator.waitForPendingOperations()

        #expect(state.captureCount == 1)
        #expect(state.clipboardReadCount == 1)
        #expect(try discovery.destinations == [IncomingURL(clipboardURL)])
        #expect(state.screenRouteCount == 0)
        #expect(state.menuOpenCount == 0)
        #expect(state.menuCloseCount == 0)

        state.eventTime = 10
        menuNotificationCenter.post(name: NSMenu.didBeginTrackingNotification, object: menu)
        state.eventTime = 20
        menuNotificationCenter.post(name: NSMenu.didEndTrackingNotification, object: menu)
        registrar.fire(.showKatabroMenu, eventTime: 15)
        #expect(state.captureCount == 1)
        #expect(state.clipboardReadCount == 1)
        #expect(state.screenRouteCount == 0)
        #expect(state.menuOpenCount == 0)
        #expect(state.menuCloseCount == 0)

        registrar.fire(.showKatabroMenu, eventTime: 21)
        #expect(state.captureCount == 1)
        #expect(state.clipboardReadCount == 1)
        #expect(state.screenRouteCount == 0)
        #expect(state.menuOpenCount == 1)
        #expect(state.menuCloseCount == 0)
        #expect(!connectedMenuPresentationState.isPresented)
    }

    private func makeBrowser() -> BrowserApplication {
        BrowserApplication(
            browser: Browser(bundleIdentifier: "com.example.browser", displayName: "Example Browser"),
            applicationURL: URL(fileURLWithPath: "/Applications/Example Browser.app"),
            icon: NSImage(size: NSSize(width: 32, height: 32))
        )
    }

    private func isolatedShortcutDefaults() -> UserDefaults {
        let suite = "AppDelegateTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("Could not create isolated shortcut defaults")
        }
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

@MainActor
private final class AppLifecycleState {
    var browserHandlers = [
        "http": "com.example.other",
        "https": "com.example.other",
    ]
    var loginItemStatus = LoginItemClient.Status.disabled
}

@MainActor
private final class ClipboardCommandState {
    var currentURL = URL(string: "https://stale.example")
    var changeCount = 1
    var readCount = 0
}

@MainActor
private final class ShortcutCallbackState {
    var captureCount = 0
    var clipboardReadCount = 0
    var screenRouteCount = 0
    var menuOpenCount = 0
    var menuCloseCount = 0
    var eventTime: TimeInterval = 0
}

@MainActor
private final class AppDelegateScreenPanelFake: ScreenURLPickerPresenting {
    func presentNearPointer() {}
    func close() {}
}

@MainActor
private final class AppDelegateRegistrarFake: GlobalHotKeyRegistering {
    private var handlers: [
        GlobalHotKeyIdentifier: @MainActor (GlobalHotKeyInvocation) -> Void
    ] = [:]
    private(set) var unregisterCalls: [GlobalHotKeyIdentifier] = []
    private(set) var registerCalls: [GlobalHotKeyIdentifier] = []

    func register(
        _: GlobalShortcut,
        for identifier: GlobalHotKeyIdentifier,
        handler: @escaping @MainActor (GlobalHotKeyInvocation) -> Void
    ) -> GlobalHotKeyRegistrationResult {
        registerCalls.append(identifier)
        handlers[identifier] = handler
        return .registered
    }

    func unregister(_ identifier: GlobalHotKeyIdentifier) {
        unregisterCalls.append(identifier)
        handlers.removeValue(forKey: identifier)
    }

    func fire(_ identifier: GlobalHotKeyIdentifier, eventTime: TimeInterval = 0) {
        handlers[identifier]?(GlobalHotKeyInvocation(eventTime: eventTime))
    }
}

// swiftlint:enable multiline_arguments type_body_length
