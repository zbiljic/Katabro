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
}

@MainActor
private final class AppLifecycleState {
    var browserHandlers = [
        "http": "com.example.other",
        "https": "com.example.other",
    ]
    var loginItemStatus = LoginItemClient.Status.disabled
}
