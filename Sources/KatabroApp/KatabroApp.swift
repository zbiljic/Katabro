import AppKit
import SwiftUI

@main
struct KatabroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                clipboardURLSnapshotStore: appDelegate.clipboardURLSnapshotStore,
                defaultBrowserClient: appDelegate.dependencies.defaultBrowserClient,
                onboardingCoordinator: appDelegate.onboardingCoordinator,
                pickerCoordinator: appDelegate.pickerCoordinator,
                screenURLCaptureCoordinator: appDelegate.screenURLCaptureCoordinator,
                screenURLCaptureSettings: appDelegate.screenURLCaptureSettings,
                preferencesStore: appDelegate.dependencies.preferencesStore,
                settingsNavigationStore: appDelegate.dependencies.settingsNavigationStore
            )
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .accessibilityLabel(AppMetadata.displayName)
        }

        Settings {
            SettingsView(
                browserDiscovery: appDelegate.dependencies.browserDiscovery,
                browserProfileStore: appDelegate.dependencies.browserProfileStore,
                defaultBrowserClient: appDelegate.dependencies.defaultBrowserClient,
                loginItemClient: appDelegate.dependencies.loginItemClient,
                screenURLCaptureSettings: appDelegate.screenURLCaptureSettings,
                screenCaptureClient: appDelegate.dependencies.screenCaptureClient,
                visionURLRecognitionClient: appDelegate.dependencies.visionURLRecognitionClient,
                preferencesStore: appDelegate.dependencies.preferencesStore,
                routingDecisionLogStore: appDelegate.dependencies.routingDecisionLogStore,
                navigationStore: appDelegate.dependencies.settingsNavigationStore,
                configurationFolderClient: appDelegate.dependencies.configurationFolderClient,
                userScriptBridge: appDelegate.dependencies.userScriptBridge,
                allowsSystemProfileConfiguration: appDelegate.dependencies.allowsSystemProfileConfiguration,
                onPreviewPicker: appDelegate.pickerCoordinator.preview
            )
        }
    }
}
