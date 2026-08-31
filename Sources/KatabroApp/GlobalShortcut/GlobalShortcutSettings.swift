import Foundation
import Observation

@MainActor
@Observable
final class GlobalShortcutSettings {
    struct Configuration: Sendable {
        let identifier: GlobalHotKeyIdentifier
        let enabledKey: String
        let shortcutKey: String
        let defaultShortcut: GlobalShortcut
        var registrationAllowed: Bool
    }

    enum RegistrationStatus: Equatable {
        case disabled
        case registered
        case conflict
        case failed

        var description: String {
            switch self {
            case .disabled: "Global shortcut is disabled."
            case .registered: "Global shortcut is registered."
            case .conflict: "This shortcut is already in use by another app or Katabro command."
            case .failed: "Katabro could not register this shortcut."
            }
        }
    }

    let configuration: Configuration
    private let defaults: UserDefaults
    private let registrar: any GlobalHotKeyRegistering
    private let onShortcut: @MainActor (GlobalHotKeyInvocation) -> Void
    private var registrationAllowed: Bool
    private var isShortcutRecording = false
    private var isRuntimeSuspended = false
    private(set) var isEnabled: Bool
    private(set) var shortcut: GlobalShortcut
    private(set) var registrationStatus: RegistrationStatus = .disabled

    var registeredDisplayValue: String {
        registrationStatus == .registered ? shortcut.displayValue : ""
    }

    convenience init(
        configuration: Configuration,
        defaults: UserDefaults = .standard,
        registrar: any GlobalHotKeyRegistering,
        onShortcut: @escaping @MainActor () -> Void = {}
    ) {
        self.init(
            configuration: configuration,
            defaults: defaults,
            registrar: registrar
        ) { _ in onShortcut() }
    }

    init(
        configuration: Configuration,
        defaults: UserDefaults = .standard,
        registrar: any GlobalHotKeyRegistering,
        onShortcut: @escaping @MainActor (GlobalHotKeyInvocation) -> Void
    ) {
        self.configuration = configuration
        self.defaults = defaults
        self.registrar = registrar
        self.onShortcut = onShortcut
        registrationAllowed = configuration.registrationAllowed
        isEnabled = defaults.bool(forKey: configuration.enabledKey)
        let storedData = defaults.data(
            forKey: configuration.shortcutKey
        )
        let storedShortcut = storedData.flatMap {
            try? JSONDecoder().decode(GlobalShortcut.self, from: $0)
        }
        shortcut = storedShortcut ?? configuration.defaultShortcut
    }

    func start() {
        registerIfNeeded()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: configuration.enabledKey)
        registerIfNeeded()
    }

    func setShortcut(_ shortcut: GlobalShortcut) {
        guard shortcut.isValid else { return }
        self.shortcut = shortcut
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: configuration.shortcutKey)
        guard !isShortcutRecording else { return }
        registerIfNeeded()
    }

    func setShortcutRecording(_ isRecording: Bool) {
        guard isShortcutRecording != isRecording else { return }
        isShortcutRecording = isRecording
        if isRecording {
            registrar.unregister(configuration.identifier)
            registrationStatus = .disabled
        } else {
            registerIfNeeded()
        }
    }

    func setRegistrationAllowed(_ allowed: Bool) {
        guard registrationAllowed != allowed else { return }
        registrationAllowed = allowed
        registerIfNeeded()
    }

    func suspendRuntimeRegistration() {
        guard !isRuntimeSuspended, registrationStatus == .registered else { return }
        isRuntimeSuspended = true
        registrar.unregister(configuration.identifier)
    }

    func resumeRuntimeRegistration() {
        guard isRuntimeSuspended else { return }
        isRuntimeSuspended = false
        registerIfNeeded()
    }

    func unregister() {
        isRuntimeSuspended = false
        registrar.unregister(configuration.identifier)
        registrationStatus = .disabled
    }

    private func registerIfNeeded() {
        registrar.unregister(configuration.identifier)
        guard registrationAllowed, isEnabled, !isShortcutRecording else {
            registrationStatus = .disabled
            return
        }
        guard !isRuntimeSuspended else {
            registrationStatus = .registered
            return
        }
        switch registrar.register(shortcut, for: configuration.identifier, handler: onShortcut) {
        case .registered: registrationStatus = .registered
        case .conflict: registrationStatus = .conflict
        case .failed: registrationStatus = .failed
        }
    }
}
