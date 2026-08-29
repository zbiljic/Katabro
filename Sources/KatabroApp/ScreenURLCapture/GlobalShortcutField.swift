import AppKit
import SwiftUI

// swiftlint:disable unused_parameter

struct GlobalShortcutField: NSViewRepresentable {
    static let recordingPrompt = "Press keys"

    let shortcut: GlobalShortcut
    let isEnabled: Bool
    let accessibilityIdentifier: String
    let onChange: (GlobalShortcut) -> Void
    let onRecordingChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> ShortcutTextField {
        let field = ShortcutTextField()
        field.delegate = context.coordinator
        field.alignment = .center
        field.bezelStyle = .roundedBezel
        field.controlSize = .small
        field.isEditable = true
        field.isSelectable = true
        field.setAccessibilityLabel("Global shortcut")
        field.setAccessibilityHelp(
            "Click, then press a shortcut with at least two modifier keys. Press Escape to cancel."
        )
        field.setAccessibilityIdentifier(accessibilityIdentifier)
        update(field, with: shortcut)
        return field
    }

    func updateNSView(_ field: ShortcutTextField, context: Context) {
        context.coordinator.parent = self
        field.isEnabled = isEnabled
        field.setAccessibilityIdentifier(accessibilityIdentifier)
        update(field, with: shortcut)
    }

    private func update(_ field: NSTextField, with shortcut: GlobalShortcut) {
        if let field = field as? ShortcutTextField, field.isRecording {
            field.stringValue = Self.recordingPrompt
            field.currentEditor()?.string = Self.recordingPrompt
            field.setAccessibilityValue(Self.recordingPrompt)
            return
        }
        if field.stringValue != shortcut.displayValue {
            field.stringValue = shortcut.displayValue
        }
        field.setAccessibilityValue(shortcut.displayValue)
    }

    final class ShortcutTextField: NSTextField {
        var isRecording = false

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            refusesFirstResponder = true
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            refusesFirstResponder = true
        }

        override func mouseDown(with event: NSEvent) {
            guard isEnabled else {
                super.mouseDown(with: event)
                return
            }
            beginPointerRecording()
            super.mouseDown(with: event)
            selectText(nil)
            guard let coordinator = delegate as? Coordinator, currentEditor() != nil else {
                endRecording()
                return
            }
            coordinator.beginRecording(in: self)
        }

        func beginPointerRecording() {
            refusesFirstResponder = false
            isRecording = true
        }

        func endRecording() {
            isRecording = false
            refusesFirstResponder = true
        }

        override func keyDown(with event: NSEvent) {
            guard
                isRecording,
                let editor = currentEditor(),
                window?.firstResponder === editor
            else {
                super.keyDown(with: event)
                return
            }
            (delegate as? Coordinator)?.record(event, in: self)
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard
                isRecording,
                let editor = currentEditor(),
                window?.firstResponder === editor
            else {
                return super.performKeyEquivalent(with: event)
            }
            (delegate as? Coordinator)?.record(event, in: self)
            return true
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: GlobalShortcutField
        private var didNotifyRecording = false

        init(parent: GlobalShortcutField) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            guard let field = notification.object as? ShortcutTextField else { return }
            beginRecording(in: field)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? ShortcutTextField, field.isRecording else { return }
            restore(field)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                restore(control)
                control.window?.makeFirstResponder(nil)
                return true
            }
            guard let field = control as? ShortcutTextField, field.isRecording else { return false }
            showRecordingPrompt(in: field)
            return true
        }

        func control(
            _ control: NSControl,
            textView _: NSTextView,
            shouldChangeCharactersIn _: NSRange,
            replacementString _: String?
        ) -> Bool {
            guard let field = control as? ShortcutTextField, field.isRecording else { return true }
            showRecordingPrompt(in: field)
            return false
        }

        func record(_ event: NSEvent, in field: NSTextField) {
            guard let shortcut = GlobalShortcut.from(event: event) else {
                showRecordingPrompt(in: field)
                return
            }
            parent.onChange(shortcut)
            field.stringValue = shortcut.displayValue
            field.setAccessibilityValue(shortcut.displayValue)
            finishRecording(field)
            field.window?.makeFirstResponder(nil)
        }

        func beginRecording(in field: ShortcutTextField) {
            field.beginPointerRecording()
            if !didNotifyRecording {
                didNotifyRecording = true
                parent.onRecordingChanged(true)
            }
            showRecordingPrompt(in: field)
        }

        private func restore(_ field: NSControl) {
            field.stringValue = parent.shortcut.displayValue
            field.setAccessibilityValue(parent.shortcut.displayValue)
            finishRecording(field)
        }

        private func showRecordingPrompt(in field: NSTextField) {
            field.stringValue = GlobalShortcutField.recordingPrompt
            field.currentEditor()?.string = GlobalShortcutField.recordingPrompt
            field.currentEditor()?.selectAll(nil)
            field.setAccessibilityValue(GlobalShortcutField.recordingPrompt)
        }

        private func finishRecording(_ field: NSControl) {
            (field as? ShortcutTextField)?.endRecording()
            if didNotifyRecording {
                didNotifyRecording = false
                parent.onRecordingChanged(false)
            }
        }
    }
}

// swiftlint:enable unused_parameter
