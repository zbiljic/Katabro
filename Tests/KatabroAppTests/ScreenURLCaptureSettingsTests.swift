import Foundation
@testable import Katabro
import Testing

// swiftlint:disable force_unwrapping
// swiftlint:disable trailing_closure

@MainActor
@Suite("Screen URL capture settings")
struct ScreenURLCaptureSettingsTests {
    @Test("defaults off and registers only after enabled")
    func enablesAndDisablesRegistration() {
        let defaults = isolatedDefaults()
        let registrar = RegistrarFake()
        let settings = ScreenURLCaptureSettings(defaults: defaults, registrar: registrar)
        #expect(settings.isCaptureEnabled)
        #expect(!settings.isEnabled)
        settings.setEnabled(true)
        #expect(settings.registrationStatus == .registered)
        #expect(registrar.registerCount == 1)
        settings.setEnabled(false)
        #expect(settings.registrationStatus == .disabled)
        #expect(registrar.unregisterCount >= 2)
    }

    @Test("master switch suspends capture while preserving shortcut preferences")
    func captureFeatureToggle() {
        let defaults = isolatedDefaults()
        let registrar = RegistrarFake()
        var calls = 0
        var cancellationCalls = 0
        let settings = ScreenURLCaptureSettings(
            defaults: defaults,
            registrar: registrar,
            onCaptureDisabled: { cancellationCalls += 1 },
            onShortcut: { calls += 1 }
        )
        settings.setEnabled(true)
        registrar.fire(identifier: .screenURLCapture)
        #expect(calls == 1)
        #expect(registrar.registerCount == 1)

        settings.setCaptureEnabled(false)
        registrar.fire(identifier: .screenURLCapture)
        #expect(!settings.isCaptureEnabled)
        #expect(settings.registrationStatus == .disabled)
        #expect(calls == 1)
        #expect(cancellationCalls == 1)

        let shortcut = GlobalShortcut(keyCode: 8, displayKey: "C", modifiers: [.command, .option])
        settings.setShortcut(shortcut)
        #expect(registrar.registerCount == 1)

        let reloadRegistrar = RegistrarFake()
        let reload = ScreenURLCaptureSettings(
            defaults: defaults,
            registrar: reloadRegistrar,
            onShortcut: { calls += 1 }
        )
        #expect(!reload.isCaptureEnabled)
        #expect(reload.isEnabled)
        #expect(reload.shortcut == shortcut)

        reload.setCaptureEnabled(true)
        reloadRegistrar.fire(identifier: .screenURLCapture)
        #expect(reload.isCaptureEnabled)
        #expect(reloadRegistrar.registerCount == 1)
        #expect(calls == 2)
    }

    @Test("unavailable recognition prevents shortcut registration")
    func unavailableCaptureDoesNotRegister() {
        let registrar = RegistrarFake()
        let settings = ScreenURLCaptureSettings(
            defaults: isolatedDefaults(),
            registrar: registrar,
            isCaptureAvailable: false
        )

        settings.setEnabled(true)

        #expect(settings.isCaptureEnabled)
        #expect(!settings.isCaptureAvailable)
        #expect(settings.registrationStatus == .disabled)
        #expect(registrar.registerCount == 0)
    }

    @Test("persists and reloads enabled shortcuts")
    func persistence() {
        let defaults = isolatedDefaults()
        let first = ScreenURLCaptureSettings(defaults: defaults, registrar: RegistrarFake())
        let shortcut = GlobalShortcut(keyCode: 8, displayKey: "C", modifiers: [.command, .option])
        first.setShortcut(shortcut)
        first.setEnabled(true)
        let reload = ScreenURLCaptureSettings(defaults: defaults, registrar: RegistrarFake())
        #expect(reload.isEnabled)
        #expect(reload.shortcut == shortcut)
    }

    @Test("updates registrations when a valid shortcut changes")
    func shortcutChangeReregisters() {
        let registrar = RegistrarFake()
        let settings = ScreenURLCaptureSettings(defaults: isolatedDefaults(), registrar: registrar)
        settings.setEnabled(true)
        settings.setShortcut(.init(keyCode: 8, displayKey: "C", modifiers: [.command, .option]))
        #expect(registrar.registerCount == 2)
        #expect(registrar.unregisterCount == 2)
    }

    @Test("ignores invalid shortcuts")
    func invalidShortcut() {
        let settings = ScreenURLCaptureSettings(defaults: isolatedDefaults(), registrar: RegistrarFake())
        let original = settings.shortcut
        settings.setShortcut(.init(keyCode: 36, displayKey: "↩", modifiers: [.command, .option]))
        #expect(settings.shortcut == original)
    }

    @Test("rejects bare, Shift-only, and reserved keys")
    func rejectedShortcutShapes() {
        let rejected = [
            GlobalShortcut(keyCode: 8, displayKey: "C", modifiers: []),
            GlobalShortcut(keyCode: 8, displayKey: "C", modifiers: [.shift]),
            GlobalShortcut(keyCode: 53, displayKey: "⎋", modifiers: [.command, .option]),
            GlobalShortcut(keyCode: 36, displayKey: "↩", modifiers: [.command, .option]),
            GlobalShortcut(keyCode: 48, displayKey: "⇥", modifiers: [.command, .option]),
        ]
        #expect(rejected.allSatisfy { !$0.isValid })
    }

    @Test(arguments: [GlobalHotKeyRegistrationResult.conflict, .failed])
    func reportsRegistrationFailures(result: GlobalHotKeyRegistrationResult) {
        let registrar = RegistrarFake(result: result)
        let settings = ScreenURLCaptureSettings(defaults: isolatedDefaults(), registrar: registrar)
        settings.setEnabled(true)
        #expect(settings.registrationStatus == (result == .conflict ? .conflict : .failed))
    }

    @Test("delivers the registered shortcut callback")
    func callbackDelivery() {
        var calls = 0
        let registrar = RegistrarFake()
        let settings = ScreenURLCaptureSettings(
            defaults: isolatedDefaults(), registrar: registrar, onShortcut: { calls += 1 }
        )
        settings.setEnabled(true)
        registrar.fire(identifier: .screenURLCapture)
        #expect(calls == 1)
    }

    @Test("refreshes permission after requesting access")
    func permissionRefresh() {
        var authorization = ScreenCaptureAuthorization.notAuthorized
        let client = ScreenCaptureClient(
            authorizationStatus: { authorization },
            requestAuthorization: { authorization = .authorized; return true },
            capture: { throw ScreenCaptureClientError.captureFailed }
        )
        let settings = ScreenURLCaptureSettings(
            defaults: isolatedDefaults(), registrar: RegistrarFake(), screenCaptureClient: client
        )
        #expect(settings.screenCaptureAuthorization == .notAuthorized)
        settings.requestScreenCaptureAuthorization()
        #expect(settings.screenCaptureAuthorization == .authorized)
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "ScreenURLCaptureSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

// swiftlint:enable force_unwrapping
// swiftlint:enable trailing_closure

@MainActor
private final class RegistrarFake: GlobalHotKeyRegistering {
    var registerCount = 0
    var unregisterCount = 0
    private let result: GlobalHotKeyRegistrationResult
    private var handlers: [GlobalHotKeyIdentifier: @MainActor () -> Void] = [:]

    init(result: GlobalHotKeyRegistrationResult = .registered) {
        self.result = result
    }

    func register(
        _: GlobalShortcut,
        for identifier: GlobalHotKeyIdentifier,
        handler: @escaping @MainActor () -> Void
    ) -> GlobalHotKeyRegistrationResult {
        registerCount += 1
        handlers[identifier] = handler
        return result
    }

    func unregister(_ identifier: GlobalHotKeyIdentifier) {
        unregisterCount += 1
        handlers.removeValue(forKey: identifier)
    }

    func fire(identifier: GlobalHotKeyIdentifier) {
        handlers[identifier]?()
    }
}
