import AppKit
import SwiftUI

@main
struct KatabroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        MenuBarExtra(
            AppMetadata.displayName,
            systemImage: "arrow.triangle.branch"
        ) {
            MenuBarView(
                defaultBrowserClient: appDelegate.dependencies.defaultBrowserClient,
                pickerCoordinator: appDelegate.pickerCoordinator,
                preferencesStore: appDelegate.dependencies.preferencesStore
            )
        }

        Window(
            "Welcome to Katabro",
            id: "onboarding"
        ) {
            OnboardingView(
                defaultBrowserClient: appDelegate.dependencies.defaultBrowserClient,
                preferencesStore: appDelegate.dependencies.preferencesStore
            )
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(
                browserDiscovery: appDelegate.dependencies.browserDiscovery,
                defaultBrowserClient: appDelegate.dependencies.defaultBrowserClient,
                loginItemClient: appDelegate.dependencies.loginItemClient,
                preferencesStore: appDelegate.dependencies.preferencesStore
            )
        }
    }
}
