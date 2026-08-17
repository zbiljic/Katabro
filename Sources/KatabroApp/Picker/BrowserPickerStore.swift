import KatabroCore
import Observation
import SwiftUI

@MainActor
@Observable
final class BrowserPickerStore {
    let destination: IncomingURL
    let targets: [BrowserLaunchTarget]
    let pickerShortcuts: [String: PickerShortcut]
    private(set) var selectedIndex: Int?
    private(set) var isRememberingSelection = false

    var canRememberSelection: Bool {
        destination.scheme == .http || destination.scheme == .https
    }

    var browsers: [BrowserApplication] {
        targets.map(\.browser)
    }

    var selectedBrowser: BrowserApplication? {
        selectedTarget?.browser
    }

    var selectedTarget: BrowserLaunchTarget? {
        guard let selectedIndex else {
            return nil
        }

        return targets[selectedIndex]
    }

    init(
        destination: IncomingURL,
        targets: [BrowserLaunchTarget],
        pickerShortcuts: [String: PickerShortcut] = [:]
    ) {
        self.destination = destination
        self.targets = targets
        self.pickerShortcuts = pickerShortcuts
        selectedIndex = targets.isEmpty ? nil : 0
    }

    convenience init(
        destination: IncomingURL,
        browsers: [BrowserApplication],
        pickerShortcuts: [String: PickerShortcut] = [:]
    ) {
        self.init(
            destination: destination,
            targets: browsers.map {
                BrowserLaunchTarget(
                    browser: $0,
                    kind: .standard
                )
            },
            pickerShortcuts: pickerShortcuts
        )
    }

    func pickerShortcut(
        for target: BrowserLaunchTarget
    ) -> PickerShortcut? {
        pickerShortcuts[target.id]
    }

    func setRememberingSelection(
        _ isRemembering: Bool
    ) {
        isRememberingSelection = canRememberSelection && isRemembering
    }

    func toggleRememberingSelection() {
        setRememberingSelection(!isRememberingSelection)
    }

    var effectiveRememberingSelection: Bool {
        canRememberSelection && isRememberingSelection
    }

    func target(
        forPickerShortcutInput input: String,
        modifiers: EventModifiers
    ) -> BrowserLaunchTarget? {
        guard
            modifiers.isDisjoint(with: [.command, .option, .control]),
            let shortcut = PickerShortcut(input)
        else {
            return nil
        }

        return targets.first {
            pickerShortcut(for: $0) == shortcut
        }
    }

    func browser(
        forPickerShortcutInput input: String,
        modifiers: EventModifiers
    ) -> BrowserApplication? {
        target(
            forPickerShortcutInput: input,
            modifiers: modifiers
        )?.browser
    }

    func select(
        index: Int
    ) {
        guard targets.indices.contains(index) else {
            return
        }

        selectedIndex = index
    }

    func moveSelection(
        by offset: Int
    ) {
        guard !targets.isEmpty else {
            selectedIndex = nil
            return
        }

        guard let selectedIndex else {
            selectedIndex = offset < 0 ? targets.index(before: targets.endIndex) : targets.startIndex
            return
        }

        let count = targets.count
        self.selectedIndex = (selectedIndex + offset % count + count) % count
    }
}
