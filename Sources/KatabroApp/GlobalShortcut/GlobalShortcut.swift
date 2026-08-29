import AppKit
import SwiftUI

// swiftlint:disable attributes is_disjoint

struct GlobalShortcut: Codable, Equatable, Sendable {
    struct Modifiers: OptionSet, Codable, Sendable {
        let rawValue: UInt
        static let command = Self(rawValue: 1 << 0)
        static let option = Self(rawValue: 1 << 1)
        static let control = Self(rawValue: 1 << 2)
        static let shift = Self(rawValue: 1 << 3)
    }

    let keyCode: UInt16
    let displayKey: String
    let modifiers: Modifiers

    static let screenURLCaptureDefault = Self(
        keyCode: 7,
        displayKey: "X",
        modifiers: [.control, .command]
    )
    static let openURLFromClipboardDefault = Self(
        keyCode: 11,
        displayKey: "B",
        modifiers: [.control, .command]
    )

    var isValid: Bool {
        modifiers.rawValue.nonzeroBitCount >= 2
            && !modifiers.intersection([.command, .option, .control]).isEmpty
            && !displayKey.isEmpty
            && ![36, 48, 53].contains(keyCode)
    }

    var displayValue: String {
        "\(modifiers.contains(.control) ? "⌃" : "")\(modifiers.contains(.option) ? "⌥" : "")\(modifiers.contains(.shift) ? "⇧" : "")\(modifiers.contains(.command) ? "⌘" : "")\(displayKey)"
    }

    var keyboardShortcut: KeyboardShortcut? {
        guard displayKey.count == 1, let character = displayKey.lowercased().first else {
            return nil
        }
        var eventModifiers: EventModifiers = []
        if modifiers.contains(.command) {
            eventModifiers.insert(.command)
        }
        if modifiers.contains(.option) {
            eventModifiers.insert(.option)
        }
        if modifiers.contains(.control) {
            eventModifiers.insert(.control)
        }
        if modifiers.contains(.shift) {
            eventModifiers.insert(.shift)
        }
        return KeyboardShortcut(KeyEquivalent(character), modifiers: eventModifiers)
    }
}

extension GlobalShortcut {
    @MainActor static func from(event: NSEvent) -> Self? {
        let modifiers = Modifiers(
            rawValue: (event.modifierFlags.contains(.command) ? Modifiers.command.rawValue : 0)
                | (event.modifierFlags.contains(.option) ? Modifiers.option.rawValue : 0)
                | (event.modifierFlags.contains(.control) ? Modifiers.control.rawValue : 0)
                | (event.modifierFlags.contains(.shift) ? Modifiers.shift.rawValue : 0)
        )
        let key = event.charactersIgnoringModifiers?.uppercased() ?? ""
        let shortcut = Self(keyCode: event.keyCode, displayKey: key, modifiers: modifiers)
        return shortcut.isValid ? shortcut : nil
    }
}

// swiftlint:enable attributes is_disjoint
