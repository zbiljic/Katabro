import AppKit
import MenuBarExtraAccess
import SwiftUI

@main
struct KatabroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        @Bindable var menuBarPresentation = appDelegate.menuBarPresentationState

        MenuBarExtra {
            MenuBarView(
                clipboardURLSnapshotStore: appDelegate.clipboardURLSnapshotStore,
                clipboardURLShortcutSettings: appDelegate.clipboardURLShortcutSettings,
                defaultBrowserClient: appDelegate.dependencies.defaultBrowserClient,
                onboardingCoordinator: appDelegate.onboardingCoordinator,
                onOpenClipboardURL: appDelegate.openClipboardURL,
                screenURLCaptureCoordinator: appDelegate.screenURLCaptureCoordinator,
                screenURLCaptureSettings: appDelegate.screenURLCaptureSettings,
                preferencesStore: appDelegate.dependencies.preferencesStore,
                settingsActionScheduler: MenuTrackingActionScheduler(),
                settingsNavigationStore: appDelegate.dependencies.settingsNavigationStore
            )
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .accessibilityLabel(AppMetadata.displayName)
        }
        .menuBarExtraAccess(isPresented: $menuBarPresentation.isPresented) { statusItem in
            guard let menu = statusItem.menu else {
                menuBarPresentation.disconnect()
                return
            }
            menuBarPresentation.connect(
                menu: menu,
                open: { [weak statusItem] in
                    statusItem?.togglePresented()
                },
                close: { [weak menu] in
                    menu?.cancelTracking()
                },
                shortcutProvider: { [weak settings = appDelegate.menuBarShortcutSettings] in
                    guard settings?.registrationStatus == .registered else { return nil }
                    return settings?.shortcut
                },
                onTrackingBegin: { [weak settings = appDelegate.menuBarShortcutSettings] in
                    settings?.suspendRuntimeRegistration()
                },
                onTrackingEnd: { [weak settings = appDelegate.menuBarShortcutSettings] in
                    settings?.resumeRuntimeRegistration()
                }
            )
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(
                browserDiscovery: appDelegate.dependencies.browserDiscovery,
                browserProfileStore: appDelegate.dependencies.browserProfileStore,
                defaultBrowserClient: appDelegate.dependencies.defaultBrowserClient,
                loginItemClient: appDelegate.dependencies.loginItemClient,
                menuBarShortcutSettings: appDelegate.menuBarShortcutSettings,
                clipboardURLShortcutSettings: appDelegate.clipboardURLShortcutSettings,
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
