import AppKit
import SwiftUI

struct PickerShortcutField: NSViewRepresentable {
    let shortcut: PickerShortcut?
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let onChange: (PickerShortcut?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(
        context: Context
    ) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.alignment = .center
        textField.bezelStyle = .roundedBezel
        textField.controlSize = .small
        textField.font = .systemFont(
            ofSize: NSFont.smallSystemFontSize
        )
        textField.placeholderString = "—"
        textField.setAccessibilityLabel(accessibilityLabel)
        textField.setAccessibilityIdentifier(accessibilityIdentifier)
        update(
            textField,
            with: shortcut
        )
        return textField
    }

    func updateNSView(
        _ textField: NSTextField,
        context: Context
    ) {
        context.coordinator.parent = self
        textField.setAccessibilityLabel(accessibilityLabel)
        textField.setAccessibilityIdentifier(accessibilityIdentifier)
        update(
            textField,
            with: shortcut
        )
    }

    private func update(
        _ textField: NSTextField,
        with shortcut: PickerShortcut?
    ) {
        let displayValue = shortcut?.displayValue ?? ""

        if textField.stringValue != displayValue {
            textField.stringValue = displayValue
        }
        textField.setAccessibilityValue(
            displayValue.isEmpty ? "—" : displayValue
        )
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PickerShortcutField

        init(
            parent: PickerShortcutField
        ) {
            self.parent = parent
        }

        func controlTextDidChange(
            _ notification: Notification
        ) {
            guard let textField = notification.object as? NSTextField else {
                return
            }

            let currentValue = parent.shortcut?.displayValue ?? ""

            guard
                let replacement = PickerShortcut.replacement(
                    in: textField.stringValue,
                    replacing: currentValue
                )
            else {
                restore(textField)
                return
            }

            parent.onChange(replacement)
            textField.stringValue = replacement.displayValue
            textField.currentEditor()?.string = replacement.displayValue
            textField.setAccessibilityValue(replacement.displayValue)
        }

        func controlTextDidBeginEditing(
            _ notification: Notification
        ) {
            guard let textField = notification.object as? NSTextField else {
                return
            }

            textField.currentEditor()?.selectAll(nil)
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.deleteBackward(_:)),
                 #selector(NSResponder.deleteForward(_:)):
                parent.onChange(nil)
                textView.string = ""
                control.stringValue = ""
                control.setAccessibilityValue("—")
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                restore(control)
                control.window?.makeFirstResponder(nil)
                return true
            default:
                return false
            }
        }

        private func restore(
            _ control: NSControl
        ) {
            let displayValue = parent.shortcut?.displayValue ?? ""
            control.stringValue = displayValue
            control.currentEditor()?.string = displayValue
            control.setAccessibilityValue(
                displayValue.isEmpty ? "—" : displayValue
            )
        }
    }
}
