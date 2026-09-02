import AppKit
import Foundation
@testable import Katabro
import Testing

// swiftlint:disable file_length force_unwrapping type_body_length

@MainActor
@Suite("Global shortcut settings")
struct GlobalShortcutSettingsTests {
    @Test("defaults off with the configured chord")
    func defaultsOff() {
        for identifier in commandIdentifiers {
            let settings = makeSettings(identifier: identifier)

            #expect(!settings.isEnabled)
            #expect(settings.shortcut == defaultShortcut(for: identifier))
            #expect(settings.registrationStatus == .disabled)
            #expect(settings.registeredDisplayValue.isEmpty)
        }
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
        #expect(settings.registeredDisplayValue == "⌃⌘B")

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

    @Test("runtime suspension is idempotent and preserves visible and persisted state")
    func runtimeSuspensionPreservesState() {
        let defaults = isolatedDefaults()
        let registrar = KeyedRegistrarFake()
        let settings = makeSettings(
            identifier: .showKatabroMenu,
            defaults: defaults,
            registrar: registrar
        )
        let replacement = GlobalShortcut(keyCode: 8, displayKey: "C", modifiers: [.command, .option])
        settings.setShortcut(replacement)
        settings.setEnabled(true)
        let unregisterCount = registrar.unregisterCalls.count

        settings.suspendRuntimeRegistration()
        settings.suspendRuntimeRegistration()

        #expect(registrar.unregisterCalls.count == unregisterCount + 1)
        #expect(registrar.registeredIdentifiers.isEmpty)
        #expect(settings.isEnabled)
        #expect(settings.shortcut == replacement)
        #expect(settings.registrationStatus == .registered)
        #expect(settings.registeredDisplayValue == replacement.displayValue)

        let reload = makeSettings(
            identifier: .showKatabroMenu,
            defaults: defaults,
            registrar: KeyedRegistrarFake()
        )
        #expect(reload.isEnabled)
        #expect(reload.shortcut == replacement)
    }

    @Test("runtime resume registers the latest shortcut exactly once")
    func runtimeResumeRegistersLatestShortcut() {
        let registrar = KeyedRegistrarFake()
        let settings = makeSettings(identifier: .showKatabroMenu, registrar: registrar)
        let replacement = GlobalShortcut(keyCode: 8, displayKey: "C", modifiers: [.command, .option])
        settings.setEnabled(true)
        settings.suspendRuntimeRegistration()
        let registerCount = registrar.registerCalls.count

        settings.setShortcut(replacement)
        #expect(registrar.registerCalls.count == registerCount)
        #expect(settings.registrationStatus == .registered)

        settings.resumeRuntimeRegistration()
        settings.resumeRuntimeRegistration()

        #expect(registrar.registerCalls.count == registerCount + 1)
        #expect(registrar.shortcuts[.showKatabroMenu] == replacement)
        #expect(settings.registrationStatus == .registered)
    }

    @Test("runtime resume exposes a registration conflict")
    func runtimeResumeExposesConflict() {
        let registrar = KeyedRegistrarFake()
        let settings = makeSettings(identifier: .showKatabroMenu, registrar: registrar)
        settings.setEnabled(true)
        settings.suspendRuntimeRegistration()
        registrar.forcedResult = .conflict

        settings.resumeRuntimeRegistration()

        #expect(registrar.registeredIdentifiers.isEmpty)
        #expect(settings.registrationStatus == .conflict)
        #expect(settings.registeredDisplayValue.isEmpty)
    }

    @Test("disabling while runtime suspended cannot re-register on resume")
    func disableWhileRuntimeSuspended() {
        let registrar = KeyedRegistrarFake()
        let settings = makeSettings(identifier: .showKatabroMenu, registrar: registrar)
        settings.setEnabled(true)
        settings.suspendRuntimeRegistration()
        let registerCount = registrar.registerCalls.count

        settings.setEnabled(false)
        settings.resumeRuntimeRegistration()

        #expect(registrar.registerCalls.count == registerCount)
        #expect(registrar.registeredIdentifiers.isEmpty)
        #expect(!settings.isEnabled)
        #expect(settings.registrationStatus == .disabled)
    }

    @Test("recording while runtime suspended resumes only after recording ends")
    func recordingWhileRuntimeSuspended() {
        let registrar = KeyedRegistrarFake()
        let settings = makeSettings(identifier: .showKatabroMenu, registrar: registrar)
        settings.setEnabled(true)
        settings.suspendRuntimeRegistration()
        let registerCount = registrar.registerCalls.count

        settings.setShortcutRecording(true)
        settings.resumeRuntimeRegistration()
        #expect(registrar.registerCalls.count == registerCount)
        #expect(settings.registrationStatus == .disabled)

        settings.setShortcutRecording(false)
        #expect(registrar.registerCalls.count == registerCount + 1)
        #expect(registrar.registeredIdentifiers == [.showKatabroMenu])
    }

    @Test("explicit unregister clears runtime suspension")
    func unregisterClearsRuntimeSuspension() {
        let registrar = KeyedRegistrarFake()
        let settings = makeSettings(identifier: .showKatabroMenu, registrar: registrar)
        settings.setEnabled(true)
        settings.suspendRuntimeRegistration()
        let registerCount = registrar.registerCalls.count

        settings.unregister()
        settings.resumeRuntimeRegistration()

        #expect(registrar.registerCalls.count == registerCount)
        #expect(registrar.registeredIdentifiers.isEmpty)
        #expect(settings.registrationStatus == .disabled)
    }

    @Test("runtime suspension isolates the menu command")
    func runtimeSuspensionIsolatesMenuCommand() {
        let registrar = KeyedRegistrarFake()
        let screen = makeSettings(identifier: .screenURLCapture, registrar: registrar)
        let clipboard = makeSettings(identifier: .openURLFromClipboard, registrar: registrar)
        let menu = makeSettings(identifier: .showKatabroMenu, registrar: registrar)
        screen.setEnabled(true)
        clipboard.setEnabled(true)
        menu.setEnabled(true)

        menu.suspendRuntimeRegistration()
        #expect(registrar.registeredIdentifiers == [.screenURLCapture, .openURLFromClipboard])

        menu.resumeRuntimeRegistration()
        #expect(registrar.registeredIdentifiers == Set(commandIdentifiers))
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
        #expect(settings.registeredDisplayValue.isEmpty)

        registrar.forcedResult = .failed
        settings.setShortcut(.init(keyCode: 8, displayKey: "C", modifiers: [.command, .option]))
        #expect(settings.registrationStatus == .failed)
        #expect(settings.shortcut.displayKey == "C")
        #expect(settings.registeredDisplayValue.isEmpty)
    }

    @Test("recording suspends and restores only its command")
    func recordingIsolation() {
        let registrar = KeyedRegistrarFake()
        let screen = makeSettings(identifier: .screenURLCapture, registrar: registrar)
        let clipboard = makeSettings(identifier: .openURLFromClipboard, registrar: registrar)
        let menu = makeSettings(identifier: .showKatabroMenu, registrar: registrar)
        screen.setEnabled(true)
        clipboard.setEnabled(true)
        menu.setEnabled(true)

        menu.setShortcutRecording(true)
        #expect(registrar.registeredIdentifiers == [.screenURLCapture, .openURLFromClipboard])
        menu.setShortcutRecording(false)
        #expect(registrar.registeredIdentifiers == Set(commandIdentifiers))
    }

    @Test("distinct commands coexist and callbacks dispatch by identifier")
    func coexistenceAndCallbackIsolation() {
        var screenCalls = 0
        var clipboardCalls = 0
        var menuCalls = 0
        let registrar = KeyedRegistrarFake()
        let screen = makeSettings(identifier: .screenURLCapture, registrar: registrar) { _ in screenCalls += 1 }
        let clipboard = makeSettings(identifier: .openURLFromClipboard, registrar: registrar) { _ in
            clipboardCalls += 1
        }
        let menu = makeSettings(identifier: .showKatabroMenu, registrar: registrar) { _ in menuCalls += 1 }
        screen.setEnabled(true)
        clipboard.setEnabled(true)
        menu.setEnabled(true)

        registrar.fire(identifier: .showKatabroMenu)
        #expect(screenCalls == 0)
        #expect(clipboardCalls == 0)
        #expect(menuCalls == 1)

        screen.setEnabled(false)
        registrar.fire(identifier: .openURLFromClipboard)
        #expect(clipboardCalls == 1)
        #expect(menuCalls == 1)
    }

    @Test("registered callbacks preserve the hotkey invocation timestamp")
    func preservesInvocationTimestamp() {
        var receivedInvocation: GlobalHotKeyInvocation?
        let registrar = KeyedRegistrarFake()
        let settings = makeSettings(registrar: registrar) { invocation in
            receivedInvocation = invocation
        }
        settings.setEnabled(true)

        registrar.fire(identifier: .openURLFromClipboard, eventTime: 42.5)

        #expect(receivedInvocation == GlobalHotKeyInvocation(eventTime: 42.5))
    }

    @Test("duplicate chords conflict on the second command and preserve the first")
    func duplicateConflict() {
        let registrar = KeyedRegistrarFake()
        let screen = makeSettings(identifier: .screenURLCapture, registrar: registrar)
        let clipboard = makeSettings(identifier: .openURLFromClipboard, registrar: registrar)
        let menu = makeSettings(identifier: .showKatabroMenu, registrar: registrar)
        screen.setEnabled(true)
        clipboard.setEnabled(true)
        menu.setShortcut(.screenURLCaptureDefault)
        menu.setEnabled(true)

        #expect(screen.registrationStatus == .registered)
        #expect(clipboard.registrationStatus == .registered)
        #expect(menu.registrationStatus == .conflict)
        #expect(registrar.registeredIdentifiers == [.screenURLCapture, .openURLFromClipboard])

        var screenCalls = 0
        var clipboardCalls = 0
        registrar.replaceHandler(for: .screenURLCapture) { _ in screenCalls += 1 }
        registrar.replaceHandler(for: .openURLFromClipboard) { _ in clipboardCalls += 1 }
        registrar.fire(identifier: .screenURLCapture)
        registrar.fire(identifier: .openURLFromClipboard)
        #expect(screenCalls == 1)
        #expect(clipboardCalls == 1)
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
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "x",
            charactersIgnoringModifiers: "x",
            isARepeat: false,
            keyCode: 7
        ))

        recorder.record(invalid, in: field)
        #expect(field.stringValue == GlobalShortcutField.recordingPrompt)
        #expect(!recorder.control(
            field,
            textView: NSTextView(),
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: "z"
        ))
        #expect(recorder.control(
            field,
            textView: NSTextView(),
            doCommandBy: #selector(NSResponder.cancelOperation(_:))
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

    @Test("recorder teardown restores its shortcut registration exactly once")
    func recorderTeardownRestoresRegistration() {
        let registrar = KeyedRegistrarFake()
        let screen = makeSettings(identifier: .screenURLCapture, registrar: registrar)
        let clipboard = makeSettings(identifier: .openURLFromClipboard, registrar: registrar)
        let menu = makeSettings(identifier: .showKatabroMenu, registrar: registrar)
        screen.setEnabled(true)
        clipboard.setEnabled(true)
        menu.setEnabled(true)
        var recordingNotifications: [Bool] = []
        let field = GlobalShortcutField.ShortcutTextField()
        let recorder = GlobalShortcutField(
            shortcut: clipboard.shortcut,
            isEnabled: clipboard.isEnabled,
            accessibilityIdentifier: "test.shortcut",
            onChange: clipboard.setShortcut
        ) {
            recordingNotifications.append($0)
            clipboard.setShortcutRecording($0)
        }.makeCoordinator()
        field.delegate = recorder
        field.stringValue = clipboard.shortcut.displayValue

        field.beginPointerRecording()
        recorder.beginRecording(in: field)
        #expect(field.stringValue == GlobalShortcutField.recordingPrompt)
        #expect(registrar.registeredIdentifiers == [.screenURLCapture, .showKatabroMenu])

        GlobalShortcutField.dismantleNSView(field, coordinator: recorder)

        #expect(field.stringValue == clipboard.shortcut.displayValue)
        #expect(field.accessibilityValue() == clipboard.shortcut.displayValue)
        #expect(!field.isRecording)
        #expect(field.refusesFirstResponder)
        #expect(recordingNotifications == [true, false])
        #expect(registrar.registeredIdentifiers == Set(commandIdentifiers))

        GlobalShortcutField.dismantleNSView(field, coordinator: recorder)

        #expect(recordingNotifications == [true, false])
        #expect(registrar.registeredIdentifiers == Set(commandIdentifiers))
    }

    @Test("callback registry rejects unknown signature and identifier")
    func callbackRegistryIsolation() {
        var screenCalls = 0
        var clipboardCalls = 0
        var menuCalls = 0
        var registry = GlobalHotKeyCallbackRegistry()
        registry.set({ _ in screenCalls += 1 }, for: .screenURLCapture)
        registry.set({ _ in clipboardCalls += 1 }, for: .openURLFromClipboard)
        registry.set({ invocation in
            #expect(invocation == GlobalHotKeyInvocation(eventTime: 12.25))
            menuCalls += 1
        }, for: .showKatabroMenu)

        let invocation = GlobalHotKeyInvocation(eventTime: 12.25)
        #expect(!registry.dispatch(signature: 0, rawIdentifier: 1, invocation: invocation))
        #expect(!registry.dispatch(
            signature: GlobalHotKeyIdentifier.signature,
            rawIdentifier: 99,
            invocation: invocation
        ))
        #expect(registry.dispatch(
            signature: GlobalHotKeyIdentifier.signature,
            rawIdentifier: GlobalHotKeyIdentifier.showKatabroMenu.rawValue,
            invocation: invocation
        ))
        #expect(screenCalls == 0)
        #expect(clipboardCalls == 0)
        #expect(menuCalls == 1)
    }

    private var commandIdentifiers: [GlobalHotKeyIdentifier] {
        [.screenURLCapture, .openURLFromClipboard, .showKatabroMenu]
    }

    private func makeSettings(
        identifier: GlobalHotKeyIdentifier = .openURLFromClipboard,
        defaults: UserDefaults? = nil,
        registrar: KeyedRegistrarFake = KeyedRegistrarFake(),
        onShortcut: @escaping @MainActor (GlobalHotKeyInvocation) -> Void = { _ in }
    ) -> GlobalShortcutSettings {
        let suffix: String
        let defaultShortcut: GlobalShortcut
        switch identifier {
        case .screenURLCapture:
            suffix = "screen"
            defaultShortcut = .screenURLCaptureDefault
        case .openURLFromClipboard:
            suffix = "clipboard"
            defaultShortcut = .openURLFromClipboardDefault
        case .showKatabroMenu:
            suffix = "menu"
            defaultShortcut = .showKatabroMenuDefault
        default:
            fatalError("Unknown test command identifier")
        }
        return GlobalShortcutSettings(
            configuration: .init(
                identifier: identifier,
                enabledKey: "test.\(suffix).enabled",
                shortcutKey: "test.\(suffix).shortcut",
                defaultShortcut: defaultShortcut,
                registrationAllowed: true
            ),
            defaults: defaults ?? isolatedDefaults(),
            registrar: registrar,
            onShortcut: onShortcut
        )
    }

    private func defaultShortcut(
        for identifier: GlobalHotKeyIdentifier
    ) -> GlobalShortcut {
        switch identifier {
        case .screenURLCapture: .screenURLCaptureDefault
        case .openURLFromClipboard: .openURLFromClipboardDefault
        case .showKatabroMenu: .showKatabroMenuDefault
        default: fatalError("Unknown test command identifier")
        }
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
    private var handlers: [
        GlobalHotKeyIdentifier: @MainActor (GlobalHotKeyInvocation) -> Void
    ] = [:]
    private(set) var registerCalls: [GlobalHotKeyIdentifier] = []
    private(set) var unregisterCalls: [GlobalHotKeyIdentifier] = []

    var registeredIdentifiers: Set<GlobalHotKeyIdentifier> {
        Set(handlers.keys)
    }

    func register(
        _ shortcut: GlobalShortcut,
        for identifier: GlobalHotKeyIdentifier,
        handler: @escaping @MainActor (GlobalHotKeyInvocation) -> Void
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

    func fire(identifier: GlobalHotKeyIdentifier, eventTime: TimeInterval = 0) {
        handlers[identifier]?(GlobalHotKeyInvocation(eventTime: eventTime))
    }

    func replaceHandler(
        for identifier: GlobalHotKeyIdentifier,
        with handler: @escaping @MainActor (GlobalHotKeyInvocation) -> Void
    ) {
        handlers[identifier] = handler
    }
}

// swiftlint:enable file_length force_unwrapping type_body_length
