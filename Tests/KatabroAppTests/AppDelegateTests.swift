import AppKit
@testable import Katabro
import KatabroCore
import Testing

// swiftlint:disable multiline_arguments

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

    @Test("termination unregisters an enabled screen URL shortcut exactly once")
    func terminationUnregistersShortcut() {
        let registrar = AppDelegateRegistrarFake()
        UserDefaults.standard.removeObject(forKey: ScreenURLCaptureSettings.enabledKey)
        defer { UserDefaults.standard.removeObject(forKey: ScreenURLCaptureSettings.enabledKey) }
        let delegate = AppDelegate(
            dependencies: AppDependencies(
                browserDiscovery: BrowserDiscoveryFake(), browserLauncher: BrowserLauncherFake(),
                defaultBrowserClient: .development(status: .notCurrent), errorPresenter: RoutingErrorPresenterFake(),
                loginItemClient: .development(status: .disabled), routingDecisionClient: .exactHostRules,
                routingDecisionLogStore: RoutingDecisionLogStore(), preferencesStore: PreferencesStore(),
                globalHotKeyRegistrar: registrar
            )
        )
        delegate.screenURLCaptureSettings.setEnabled(true)
        let beforeTermination = registrar.unregisterCount
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        #expect(registrar.unregisterCount == beforeTermination + 1)
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
private final class AppDelegateRegistrarFake: GlobalHotKeyRegistering {
    var unregisterCount = 0
    func register(
        _: GlobalShortcut,
        handler _: @escaping @MainActor () -> Void
    ) -> GlobalHotKeyRegistrationResult {
        .registered
    }

    func unregister() {
        unregisterCount += 1
    }
}

// swiftlint:enable multiline_arguments
