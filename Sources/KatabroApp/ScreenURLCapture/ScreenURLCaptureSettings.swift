import Foundation
import Observation

// swiftlint:disable opening_brace

@MainActor
@Observable
final class ScreenURLCaptureSettings {
    enum RegistrationStatus: Equatable {
        case disabled
        case registered
        case conflict
        case failed

        var description: String {
            switch self {
            case .disabled: "Global shortcut is disabled."
            case .registered: "Global shortcut is registered."
            case .conflict: "This shortcut is already in use by another app."
            case .failed: "Katabro could not register this shortcut."
            }
        }
    }

    static let captureEnabledKey = "screenURLCapture.enabled.v1"
    static let enabledKey = "screenURLCapture.globalShortcutEnabled.v1"
    static let shortcutKey = "screenURLCapture.globalShortcut.v1"

    private let defaults: UserDefaults
    private let registrar: any GlobalHotKeyRegistering
    private let screenCaptureClient: ScreenCaptureClient
    private let onCaptureDisabled: @MainActor () -> Void
    private let onShortcut: @MainActor () -> Void
    private var isShortcutRecording = false
    private(set) var isCaptureEnabled: Bool
    private(set) var isCaptureAvailable: Bool
    private(set) var isEnabled: Bool
    private(set) var shortcut: GlobalShortcut
    private(set) var registrationStatus: RegistrationStatus = .disabled
    private(set) var screenCaptureAuthorization: ScreenCaptureAuthorization

    init(
        defaults: UserDefaults = .standard,
        registrar: any GlobalHotKeyRegistering,
        screenCaptureClient: ScreenCaptureClient = .inert,
        isCaptureAvailable: Bool = true,
        onCaptureDisabled: @escaping @MainActor () -> Void = {},
        onShortcut: @escaping @MainActor () -> Void = {}
    ) {
        self.defaults = defaults
        self.registrar = registrar
        self.screenCaptureClient = screenCaptureClient
        self.isCaptureAvailable = isCaptureAvailable
        self.onCaptureDisabled = onCaptureDisabled
        self.onShortcut = onShortcut
        screenCaptureAuthorization = screenCaptureClient.authorizationStatus()
        isCaptureEnabled = defaults.object(forKey: Self.captureEnabledKey) == nil
            ? true
            : defaults.bool(forKey: Self.captureEnabledKey)
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        if
            let data = defaults.data(forKey: Self.shortcutKey), let stored = try? JSONDecoder().decode(
                GlobalShortcut.self,
                from: data
            )
        {
            shortcut = stored
        } else {
            shortcut = .default
        }
    }

    func start() {
        refreshScreenCaptureAuthorization()
        registerIfNeeded()
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
        registerIfNeeded()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
        registerIfNeeded()
    }

    func setShortcut(_ shortcut: GlobalShortcut) {
        guard shortcut.isValid else { return }
        self.shortcut = shortcut
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: Self.shortcutKey)
        guard !isShortcutRecording else { return }
        registerIfNeeded()
    }

    func setShortcutRecording(_ isRecording: Bool) {
        guard isShortcutRecording != isRecording else { return }
        isShortcutRecording = isRecording
        if isRecording {
            registrar.unregister()
        } else {
            registerIfNeeded()
        }
    }

    func unregister() {
        registrar.unregister()
        registrationStatus = .disabled
    }

    private func registerIfNeeded() {
        registrar.unregister()
        guard isCaptureEnabled, isCaptureAvailable, isEnabled else {
            registrationStatus = .disabled
            return
        }
        switch registrar.register(shortcut, handler: onShortcut) {
        case .registered: registrationStatus = .registered
        case .conflict: registrationStatus = .conflict
        case .failed: registrationStatus = .failed
        }
    }
}

// swiftlint:enable opening_brace
