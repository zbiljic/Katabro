import AppKit
import Foundation
@testable import Katabro
import Testing

// swiftlint:disable force_unwrapping trailing_closure

@MainActor
@Suite("Global shortcut settings")
struct GlobalShortcutSettingsTests {
    @Test("defaults off with the configured chord")
    func defaultsOff() {
        let settings = makeSettings(identifier: .openURLFromClipboard)

        #expect(!settings.isEnabled)
        #expect(settings.shortcut == .openURLFromClipboardDefault)
        #expect(settings.registrationStatus == .disabled)
    }

    @Test("enables, changes, persists, and disables one registration")
    func lifecycleAndPersistence() {
        let defaults = isolatedDefaults()
        let registrar = KeyedRegistrarFake()
        let settings = makeSettings(defaults: defaults, registrar: registrar)
        let replacement = GlobalShortcut(keyCode: 8, displayKey: "C", modifiers: [.command, .option])

        settings.setEnabled(true)
        #expect(registrar.registeredIdentifiers == [.openURLFromClipboard])
        #expect(settings.registrationStatus == .registered)

        settings.setShortcut(replacement)
        #expect(registrar.shortcuts[.openURLFromClipboard] == replacement)
        #expect(settings.shortcut == replacement)

        let reload = makeSettings(defaults: defaults, registrar: KeyedRegistrarFake())
        #expect(reload.isEnabled)
        #expect(reload.shortcut == replacement)

        settings.setEnabled(false)
        #expect(registrar.registeredIdentifiers.isEmpty)
        #expect(settings.registrationStatus == .disabled)
    }

    @Test("invalid shortcuts are retained and registration errors preserve the chosen chord")
    func validationAndFailure() {
        let registrar = KeyedRegistrarFake()
        let settings = makeSettings(registrar: registrar)
        let original = settings.shortcut
        settings.setShortcut(.init(keyCode: 36, displayKey: "↩", modifiers: [.command, .option]))
        #expect(settings.shortcut == original)

        registrar.forcedResult = .conflict
        settings.setEnabled(true)
        #expect(settings.registrationStatus == .conflict)
        #expect(settings.shortcut == original)

        registrar.forcedResult = .failed
        settings.setShortcut(.init(keyCode: 8, displayKey: "C", modifiers: [.command, .option]))
        #expect(settings.registrationStatus == .failed)
        #expect(settings.shortcut.displayKey == "C")
    }

    @Test("recording suspends and restores only its command")
    func recordingIsolation() {
        let registrar = KeyedRegistrarFake()
        let screen = makeSettings(identifier: .screenURLCapture, registrar: registrar)
        let clipboard = makeSettings(identifier: .openURLFromClipboard, registrar: registrar)
        screen.setEnabled(true)
        clipboard.setEnabled(true)

        clipboard.setShortcutRecording(true)
        #expect(registrar.registeredIdentifiers == [.screenURLCapture])
        clipboard.setShortcutRecording(false)
        #expect(registrar.registeredIdentifiers == [.screenURLCapture, .openURLFromClipboard])
    }

    @Test("distinct commands coexist and callbacks dispatch by identifier")
    func coexistenceAndCallbackIsolation() {
        var screenCalls = 0
        var clipboardCalls = 0
        let registrar = KeyedRegistrarFake()
        let screen = makeSettings(identifier: .screenURLCapture, registrar: registrar) { screenCalls += 1 }
        let clipboard = makeSettings(identifier: .openURLFromClipboard, registrar: registrar) { clipboardCalls += 1 }
        screen.setEnabled(true)
        clipboard.setEnabled(true)

        registrar.fire(identifier: .openURLFromClipboard)
        #expect(screenCalls == 0)
        #expect(clipboardCalls == 1)

        screen.setEnabled(false)
        registrar.fire(identifier: .openURLFromClipboard)
        #expect(clipboardCalls == 2)
    }

    @Test("duplicate chords conflict on the second command and preserve the first")
    func duplicateConflict() {
        let registrar = KeyedRegistrarFake()
        let screen = makeSettings(identifier: .screenURLCapture, registrar: registrar)
        let clipboard = makeSettings(identifier: .openURLFromClipboard, registrar: registrar)
        screen.setEnabled(true)
        clipboard.setShortcut(.screenURLCaptureDefault)
        clipboard.setEnabled(true)

        #expect(screen.registrationStatus == .registered)
        #expect(clipboard.registrationStatus == .conflict)
        #expect(registrar.registeredIdentifiers == [.screenURLCapture])
    }

    @Test("availability unregisters only that command without erasing preferences")
    func availabilityIsolation() {
        let registrar = KeyedRegistrarFake()
        let screen = makeSettings(identifier: .screenURLCapture, registrar: registrar)
        let clipboard = makeSettings(identifier: .openURLFromClipboard, registrar: registrar)
        screen.setEnabled(true)
        clipboard.setEnabled(true)

        screen.setRegistrationAllowed(false)
        #expect(screen.registrationStatus == .disabled)
        #expect(screen.isEnabled)
        #expect(registrar.registeredIdentifiers == [.openURLFromClipboard])
    }

    @Test("recorder rejects raw text and restores on Escape")
    func recorderValidation() throws {
        let field = GlobalShortcutField.ShortcutTextField()
        let shortcut = GlobalShortcut.screenURLCaptureDefault
        let recorder = GlobalShortcutField(
            shortcut: shortcut,
            isEnabled: true,
            accessibilityIdentifier: "test.shortcut",
            onChange: { _ in },
            onRecordingChanged: { _ in }
        ).makeCoordinator()
        field.delegate = recorder
        field.stringValue = shortcut.displayValue
        field.beginPointerRecording()
        recorder.beginRecording(in: field)
        let invalid = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: "x", charactersIgnoringModifiers: "x",
            isARepeat: false, keyCode: 7
        ))

        recorder.record(invalid, in: field)
        #expect(field.stringValue == GlobalShortcutField.recordingPrompt)
        #expect(!recorder.control(
            field, textView: NSTextView(),
            shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "z"
        ))
        #expect(recorder.control(
            field, textView: NSTextView(), doCommandBy: #selector(NSResponder.cancelOperation(_:))
        ))
        #expect(field.stringValue == shortcut.displayValue)
        #expect(!field.isRecording)
    }

    @Test("recorder arms only for explicit pointer interaction")
    func recorderRequiresPointerInteraction() {
        let field = GlobalShortcutField.ShortcutTextField()
        #expect(field.refusesFirstResponder)
        field.beginPointerRecording()
        #expect(!field.refusesFirstResponder)
        #expect(field.isRecording)
        field.endRecording()
        #expect(field.refusesFirstResponder)
        #expect(!field.isRecording)
    }

    @Test("callback registry rejects unknown signature and identifier")
    func callbackRegistryIsolation() {
        var screenCalls = 0
        var clipboardCalls = 0
        var registry = GlobalHotKeyCallbackRegistry()
        registry.set({ screenCalls += 1 }, for: .screenURLCapture)
        registry.set({ clipboardCalls += 1 }, for: .openURLFromClipboard)

        #expect(!registry.dispatch(signature: 0, rawIdentifier: 1))
        #expect(!registry.dispatch(signature: GlobalHotKeyIdentifier.signature, rawIdentifier: 99))
        #expect(registry.dispatch(
            signature: GlobalHotKeyIdentifier.signature,
            rawIdentifier: GlobalHotKeyIdentifier.openURLFromClipboard.rawValue
        ))
        #expect(screenCalls == 0)
        #expect(clipboardCalls == 1)
    }

    private func makeSettings(
        identifier: GlobalHotKeyIdentifier = .openURLFromClipboard,
        defaults: UserDefaults? = nil,
        registrar: KeyedRegistrarFake = KeyedRegistrarFake(),
        onShortcut: @escaping @MainActor () -> Void = {}
    ) -> GlobalShortcutSettings {
        let suffix = identifier == .screenURLCapture ? "screen" : "clipboard"
        return GlobalShortcutSettings(
            configuration: .init(
                identifier: identifier,
                enabledKey: "test.\(suffix).enabled",
                shortcutKey: "test.\(suffix).shortcut",
                defaultShortcut: identifier == .screenURLCapture
                    ? .screenURLCaptureDefault
                    : .openURLFromClipboardDefault,
                registrationAllowed: true
            ),
            defaults: defaults ?? isolatedDefaults(),
            registrar: registrar,
            onShortcut: onShortcut
        )
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "GlobalShortcutSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

@MainActor
final class KeyedRegistrarFake: GlobalHotKeyRegistering {
    var forcedResult: GlobalHotKeyRegistrationResult?
    private(set) var shortcuts: [GlobalHotKeyIdentifier: GlobalShortcut] = [:]
    private var handlers: [GlobalHotKeyIdentifier: @MainActor () -> Void] = [:]
    private(set) var registerCalls: [GlobalHotKeyIdentifier] = []
    private(set) var unregisterCalls: [GlobalHotKeyIdentifier] = []

    var registeredIdentifiers: Set<GlobalHotKeyIdentifier> {
        Set(handlers.keys)
    }

    func register(
        _ shortcut: GlobalShortcut,
        for identifier: GlobalHotKeyIdentifier,
        handler: @escaping @MainActor () -> Void
    ) -> GlobalHotKeyRegistrationResult {
        registerCalls.append(identifier)
        if let forcedResult {
            return forcedResult
        }
        if shortcuts.contains(where: { $0.key != identifier && $0.value == shortcut }) {
            return .conflict
        }
        shortcuts[identifier] = shortcut
        handlers[identifier] = handler
        return .registered
    }

    func unregister(_ identifier: GlobalHotKeyIdentifier) {
        unregisterCalls.append(identifier)
        shortcuts.removeValue(forKey: identifier)
        handlers.removeValue(forKey: identifier)
    }

    func fire(identifier: GlobalHotKeyIdentifier) {
        handlers[identifier]?()
    }
}

// swiftlint:enable force_unwrapping trailing_closure
