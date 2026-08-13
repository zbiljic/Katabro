import KatabroCore
import Observation
import SwiftUI

@MainActor
@Observable
final class BrowserPickerStore {
    let destination: IncomingURL
    let browsers: [BrowserApplication]
    let pickerShortcuts: [String: PickerShortcut]
    private(set) var selectedIndex: Int?

    var selectedBrowser: BrowserApplication? {
        guard let selectedIndex else {
            return nil
        }

        return browsers[selectedIndex]
    }

    init(
        destination: IncomingURL,
        browsers: [BrowserApplication],
        pickerShortcuts: [String: PickerShortcut] = [:]
    ) {
        self.destination = destination
        self.browsers = browsers
        self.pickerShortcuts = pickerShortcuts
        selectedIndex = browsers.isEmpty ? nil : 0
    }

    func pickerShortcut(
        for browser: BrowserApplication
    ) -> PickerShortcut? {
        pickerShortcuts[
            browser.browser.bundleIdentifier
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        ]
    }

    func browser(
        forPickerShortcutInput input: String,
        modifiers: EventModifiers
    ) -> BrowserApplication? {
        guard
            modifiers.isDisjoint(with: [.command, .option, .control]),
            let shortcut = PickerShortcut(input)
        else {
            return nil
        }

        return browsers.first {
            pickerShortcut(for: $0) == shortcut
        }
    }

    func select(
        index: Int
    ) {
        guard browsers.indices.contains(index) else {
            return
        }

        selectedIndex = index
    }

    func moveSelection(
        by offset: Int
    ) {
        guard !browsers.isEmpty else {
            selectedIndex = nil
            return
        }

        guard let selectedIndex else {
            selectedIndex = offset < 0 ? browsers.index(before: browsers.endIndex) : browsers.startIndex
            return
        }

        let count = browsers.count
        self.selectedIndex = (selectedIndex + offset % count + count) % count
    }
}
