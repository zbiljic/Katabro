import Carbon

// swiftlint:disable multiline_arguments

@MainActor
enum GlobalHotKeyRegistrationResult: Equatable {
    case registered
    case conflict
    case failed
}

@MainActor
protocol GlobalHotKeyRegistering: AnyObject {
    func register(_ shortcut: GlobalShortcut, handler: @escaping @MainActor () -> Void)
        -> GlobalHotKeyRegistrationResult
    func unregister()
}

@MainActor
final class GlobalHotKeyRegistrar: GlobalHotKeyRegistering {
    private var eventHotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var callback: (@MainActor () -> Void)?

    func register(
        _ shortcut: GlobalShortcut,
        handler: @escaping @MainActor () -> Void
    ) -> GlobalHotKeyRegistrationResult {
        unregister()
        guard shortcut.isValid else { return .failed }
        callback = handler
        let types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))]
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let registrar = Unmanaged<GlobalHotKeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
            registrar.callback?()
            return noErr
        }, 1, types, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        guard status == noErr else { callback = nil; return .failed }
        let modifiers = carbonModifiers(for: shortcut.modifiers)
        let id = EventHotKeyID(signature: OSType(0x4B41_5452), id: 1)
        let registration = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            modifiers,
            id,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive),
            &eventHotKey
        )
        if registration == eventHotKeyExistsErr {
            unregister(); return .conflict
        }
        guard registration == noErr else { unregister(); return .failed }
        return .registered
    }

    func unregister() {
        if let eventHotKey {
            UnregisterEventHotKey(eventHotKey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHotKey = nil
        eventHandler = nil
        callback = nil
    }

    private func carbonModifiers(for modifiers: GlobalShortcut.Modifiers) -> UInt32 {
        (modifiers.contains(.command) ? UInt32(cmdKey) : 0)
            | (modifiers.contains(.option) ? UInt32(optionKey) : 0)
            | (modifiers.contains(.control) ? UInt32(controlKey) : 0)
            | (modifiers.contains(.shift) ? UInt32(shiftKey) : 0)
    }
}

@MainActor
final class InertGlobalHotKeyRegistrar: GlobalHotKeyRegistering {
    func register(
        _: GlobalShortcut,
        handler _: @escaping @MainActor () -> Void
    ) -> GlobalHotKeyRegistrationResult {
        .failed
    }

    func unregister() {}
}

// swiftlint:enable multiline_arguments
