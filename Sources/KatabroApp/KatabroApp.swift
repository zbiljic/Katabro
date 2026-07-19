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
                onboardingCoordinator: appDelegate.onboardingCoordinator,
                pickerCoordinator: appDelegate.pickerCoordinator,
                preferencesStore: appDelegate.dependencies.preferencesStore
            )
        }

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
