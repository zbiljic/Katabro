import Carbon

// swiftlint:disable multiline_arguments

struct GlobalHotKeyIdentifier: RawRepresentable, Hashable, Sendable {
    static let signature: UInt32 = 0x4B41_5452
    static let screenURLCapture = Self(rawValue: 1)
    static let openURLFromClipboard = Self(rawValue: 2)

    let rawValue: UInt32
}

@MainActor
enum GlobalHotKeyRegistrationResult: Equatable {
    case registered
    case conflict
    case failed
}

@MainActor
protocol GlobalHotKeyRegistering: AnyObject {
    func register(
        _ shortcut: GlobalShortcut,
        for identifier: GlobalHotKeyIdentifier,
        handler: @escaping @MainActor () -> Void
    ) -> GlobalHotKeyRegistrationResult
    func unregister(_ identifier: GlobalHotKeyIdentifier)
}

@MainActor
struct GlobalHotKeyCallbackRegistry {
    private var callbacks: [GlobalHotKeyIdentifier: @MainActor () -> Void] = [:]

    mutating func set(
        _ callback: @escaping @MainActor () -> Void,
        for identifier: GlobalHotKeyIdentifier
    ) {
        callbacks[identifier] = callback
    }

    mutating func remove(_ identifier: GlobalHotKeyIdentifier) {
        callbacks.removeValue(forKey: identifier)
    }

    func dispatch(signature: UInt32, rawIdentifier: UInt32) -> Bool {
        guard signature == GlobalHotKeyIdentifier.signature else { return false }
        guard let callback = callbacks[GlobalHotKeyIdentifier(rawValue: rawIdentifier)] else { return false }
        callback()
        return true
    }
}

@MainActor
final class GlobalHotKeyRegistrar: GlobalHotKeyRegistering {
    private var eventHotKeys: [GlobalHotKeyIdentifier: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var callbacks = GlobalHotKeyCallbackRegistry()

    func register(
        _ shortcut: GlobalShortcut,
        for identifier: GlobalHotKeyIdentifier,
        handler: @escaping @MainActor () -> Void
    ) -> GlobalHotKeyRegistrationResult {
        unregister(identifier)
        guard shortcut.isValid else { return .failed }
        guard installEventHandlerIfNeeded() else { return .failed }

        var eventHotKey: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(
            signature: OSType(GlobalHotKeyIdentifier.signature),
            id: identifier.rawValue
        )
        let registration = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            carbonModifiers(for: shortcut.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive),
            &eventHotKey
        )
        if registration == eventHotKeyExistsErr {
            removeEventHandlerIfUnused()
            return .conflict
        }
        guard registration == noErr, let eventHotKey else {
            removeEventHandlerIfUnused()
            return .failed
        }
        eventHotKeys[identifier] = eventHotKey
        callbacks.set(handler, for: identifier)
        return .registered
    }

    func unregister(_ identifier: GlobalHotKeyIdentifier) {
        if let eventHotKey = eventHotKeys.removeValue(forKey: identifier) {
            UnregisterEventHotKey(eventHotKey)
        }
        callbacks.remove(identifier)
        removeEventHandlerIfUnused()
    }

    private func installEventHandlerIfNeeded() -> Bool {
        guard eventHandler == nil else { return true }
        let types = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
        ]
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let registrar = Unmanaged<GlobalHotKeyRegistrar>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                return MainActor.assumeIsolated {
                    registrar.handle(event)
                }
            },
            types.count,
            types,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        return status == noErr
    }

    private func handle(_ event: EventRef) -> OSStatus {
        var identifier = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &identifier
        )
        guard status == noErr else { return OSStatus(eventNotHandledErr) }
        return callbacks.dispatch(
            signature: identifier.signature,
            rawIdentifier: identifier.id
        ) ? OSStatus(noErr) : OSStatus(eventNotHandledErr)
    }

    private func removeEventHandlerIfUnused() {
        guard eventHotKeys.isEmpty, let eventHandler else { return }
        RemoveEventHandler(eventHandler)
        self.eventHandler = nil
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
        for _: GlobalHotKeyIdentifier,
        handler _: @escaping @MainActor () -> Void
    ) -> GlobalHotKeyRegistrationResult {
        .failed
    }

    func unregister(_: GlobalHotKeyIdentifier) {}
}

// swiftlint:enable multiline_arguments
