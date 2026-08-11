import AppKit
import SwiftUI

@main
struct KatabroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                defaultBrowserClient: appDelegate.dependencies.defaultBrowserClient,
                onboardingCoordinator: appDelegate.onboardingCoordinator,
                pickerCoordinator: appDelegate.pickerCoordinator,
                preferencesStore: appDelegate.dependencies.preferencesStore
            )
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .accessibilityLabel(AppMetadata.displayName)
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
