import Foundation
import Observation

// swiftlint:disable opening_brace

@MainActor
@Observable
final class ScreenURLCaptureSettings {
    typealias RegistrationStatus = GlobalShortcutSettings.RegistrationStatus

    static let captureEnabledKey = "screenURLCapture.enabled.v1"
    static let enabledKey = "screenURLCapture.globalShortcutEnabled.v1"
    static let shortcutKey = "screenURLCapture.globalShortcut.v1"

    let globalShortcutSettings: GlobalShortcutSettings
    private let defaults: UserDefaults
    private let screenCaptureClient: ScreenCaptureClient
    private let onCaptureDisabled: @MainActor () -> Void
    private(set) var isCaptureEnabled: Bool
    private(set) var isCaptureAvailable: Bool
    private(set) var screenCaptureAuthorization: ScreenCaptureAuthorization

    var isEnabled: Bool {
        globalShortcutSettings.isEnabled
    }

    var shortcut: GlobalShortcut {
        globalShortcutSettings.shortcut
    }

    var registrationStatus: RegistrationStatus {
        globalShortcutSettings.registrationStatus
    }

    init(
        defaults: UserDefaults = .standard,
        registrar: any GlobalHotKeyRegistering,
        screenCaptureClient: ScreenCaptureClient = .inert,
        isCaptureAvailable: Bool = true,
        onCaptureDisabled: @escaping @MainActor () -> Void = {},
        onShortcut: @escaping @MainActor () -> Void = {}
    ) {
        self.defaults = defaults
        self.screenCaptureClient = screenCaptureClient
        self.isCaptureAvailable = isCaptureAvailable
        self.onCaptureDisabled = onCaptureDisabled
        screenCaptureAuthorization = screenCaptureClient.authorizationStatus()
        let captureEnabled = defaults.object(forKey: Self.captureEnabledKey) == nil
            ? true
            : defaults.bool(forKey: Self.captureEnabledKey)
        isCaptureEnabled = captureEnabled
        globalShortcutSettings = GlobalShortcutSettings(
            configuration: .init(
                identifier: .screenURLCapture,
                enabledKey: Self.enabledKey,
                shortcutKey: Self.shortcutKey,
                defaultShortcut: .screenURLCaptureDefault,
                registrationAllowed: isCaptureAvailable && captureEnabled
            ),
            defaults: defaults,
            registrar: registrar,
            onShortcut: onShortcut
        )
    }

    func start() {
        refreshScreenCaptureAuthorization()
        globalShortcutSettings.setRegistrationAllowed(isCaptureEnabled && isCaptureAvailable)
        globalShortcutSettings.start()
    }

    func refreshScreenCaptureAuthorization() {
        screenCaptureAuthorization = screenCaptureClient.authorizationStatus()
    }

    func requestScreenCaptureAuthorization() {
        _ = screenCaptureClient.requestAuthorization()
        refreshScreenCaptureAuthorization()
    }

    func setCaptureEnabled(_ enabled: Bool) {
        guard isCaptureEnabled != enabled else { return }
        isCaptureEnabled = enabled
        defaults.set(enabled, forKey: Self.captureEnabledKey)
        if !enabled {
            onCaptureDisabled()
        }
        globalShortcutSettings.setRegistrationAllowed(isCaptureEnabled && isCaptureAvailable)
    }

    func setEnabled(_ enabled: Bool) {
        globalShortcutSettings.setEnabled(enabled)
    }

    func setShortcut(_ shortcut: GlobalShortcut) {
        globalShortcutSettings.setShortcut(shortcut)
    }

    func setShortcutRecording(_ isRecording: Bool) {
        globalShortcutSettings.setShortcutRecording(isRecording)
    }

    func unregister() {
        globalShortcutSettings.unregister()
    }
}

// swiftlint:enable opening_brace
