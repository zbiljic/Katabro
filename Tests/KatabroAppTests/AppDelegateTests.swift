import AppKit
@testable import Katabro
import Testing

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
                preferencesStore: store
            )
        )

        delegate.applicationDidBecomeActive(
            Notification(name: NSApplication.didBecomeActiveNotification)
        )
        #expect(refreshCount == 1)
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
