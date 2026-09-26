import AppKit
@testable import Katabro
import KatabroCore
import SwiftUI
import Testing

@MainActor
@Suite("Browser picker state")
struct BrowserPickerStoreTests {
    @Test("remember selection defaults off and can be toggled")
    func togglesRememberSelection() throws {
        let store = try BrowserPickerStore(
            destination: IncomingURL("https://example.com"),
            browsers: [makeBrowser(identifier: "com.example.browser", name: "Browser")]
        )

        #expect(!store.isRememberingSelection)
        store.setRememberingSelection(true)
        #expect(store.isRememberingSelection)
    }

    @Test("remember eligibility requires targets and the visual preference")
    func rememberEligibilityUsesPreference() throws {
        let browser = makeBrowser(identifier: "com.example.browser", name: "Browser")
        let empty = try BrowserPickerStore(destination: IncomingURL("https://example.com"), browsers: [])
        let hidden = try BrowserPickerStore(
            destination: IncomingURL("https://example.com"),
            browsers: [browser],
            pickerPreferences: BrowserPickerPreferences(showsRememberChoice: false)
        )

        #expect(!empty.canRememberSelection)
        #expect(!hidden.canRememberSelection)
        hidden.setRememberingSelection(true)
        #expect(!hidden.effectiveRememberingSelection)
    }

    @Test("retains its presentation preference snapshot")
    func retainsPreferenceSnapshot() throws {
        let preferences = BrowserPickerPreferences(
            orientation: .horizontal,
            verticalWidth: .compact,
            visibleChoiceCount: 8,
            destinationDisplay: .hidden,
            shortcutHintMode: .numbersOnly,
            horizontalLabelMode: .all,
            showsRememberChoice: false
        )
        let store = try BrowserPickerStore(
            destination: IncomingURL("https://example.com"),
            browsers: [makeBrowser(identifier: "com.example.browser", name: "Browser")],
            pickerPreferences: preferences
        )
        #expect(store.pickerPreferences == preferences)
    }

    @Test("file destinations cannot remember a selection")
    func fileDestinationCannotRememberSelection() throws {
        let store = try BrowserPickerStore(
            destination: IncomingURL("file://localhost/tmp/example.html"),
            browsers: []
        )

        #expect(!store.canRememberSelection)
        store.setRememberingSelection(true)
        store.toggleRememberingSelection()
        #expect(!store.isRememberingSelection)
        #expect(!store.effectiveRememberingSelection)
    }

    @Test("looks up custom picker shortcuts case-insensitively")
    func looksUpPickerShortcuts() throws {
        let first = makeBrowser(
            identifier: "com.example.first",
            name: "First"
        )
        let second = makeBrowser(
            identifier: "com.example.second",
            name: "Second"
        )
        let store = try BrowserPickerStore(
            destination: IncomingURL("https://example.com"),
            browsers: [first, second],
            pickerShortcuts: [
                "com.example.second": #require(PickerShortcut("s")),
            ]
        )

        #expect(
            store.browser(
                forPickerShortcutInput: "s",
                modifiers: []
            ) == second
        )
        #expect(
            store.browser(
                forPickerShortcutInput: "S",
                modifiers: [.shift]
            ) == second
        )
        #expect(
            store.browser(
                forPickerShortcutInput: "s",
                modifiers: [.capsLock]
            ) == second
        )
        #expect(
            store.browser(
                forPickerShortcutInput: "f",
                modifiers: []
            ) == nil
        )
    }

    @Test(
        "ignores command-producing picker shortcut modifiers",
        arguments: [
            EventModifiers.command,
            EventModifiers.option,
            EventModifiers.control,
            [EventModifiers.command, .shift],
        ]
    )
    func ignoresCommandModifiers(
        modifiers: EventModifiers
    ) throws {
        let browser = makeBrowser(
            identifier: "com.example.browser",
            name: "Browser"
        )
        let store = try BrowserPickerStore(
            destination: IncomingURL("https://example.com"),
            browsers: [browser],
            pickerShortcuts: [
                "com.example.browser": #require(PickerShortcut("b")),
            ]
        )

        #expect(
            store.browser(
                forPickerShortcutInput: "b",
                modifiers: modifiers
            ) == nil
        )
    }

    @Test("numeric shortcuts follow full target order", arguments: [1, 5, 9])
    func numericShortcutsUseFullOrder(number: Int) throws {
        let targets = (1 ... 12).map { index in
            BrowserLaunchTarget(
                browser: makeBrowser(identifier: "com.example.\(index)", name: "Browser \(index)"),
                kind: .standard
            )
        }
        for orderedTargets in [targets, Array(targets.reversed())] {
            let store = try BrowserPickerStore(
                destination: IncomingURL("https://example.com"),
                targets: orderedTargets,
                pickerPreferences: BrowserPickerPreferences(visibleChoiceCount: 3)
            )
            #expect(
                store.target(forPickerShortcutInput: String(number), modifiers: [])?.id
                    == orderedTargets[number - 1].id
            )
        }
    }

    @Test("numeric shortcuts distinguish targets sharing one browser")
    func numericShortcutsDistinguishTargetKinds() throws {
        let browser = makeBrowser(identifier: "com.google.Chrome", name: "Chrome")
        let targets = [
            BrowserLaunchTarget(browser: browser, kind: .standard),
            BrowserLaunchTarget(browser: browser, kind: .privateWindow(.chromium)),
            BrowserLaunchTarget(
                browser: browser,
                kind: .profile(BrowserProfile(
                    identifier: "work",
                    displayName: "Work",
                    launchValue: "Profile 2",
                    family: .chromium
                ))
            ),
        ]
        let store = try BrowserPickerStore(destination: IncomingURL("https://example.com"), targets: targets)
        for number in 1 ... 3 {
            #expect(store.target(forPickerShortcutInput: String(number), modifiers: [])?.id == targets[number - 1].id)
        }
    }

    @Test("numeric shortcuts ignore hint presentation", arguments: BrowserPickerShortcutHintMode.allCases)
    func numericShortcutsIgnoreHints(mode: BrowserPickerShortcutHintMode) throws {
        let store = try BrowserPickerStore(
            destination: IncomingURL("https://example.com"),
            browsers: [makeBrowser(identifier: "com.example.browser", name: "Browser")],
            pickerPreferences: BrowserPickerPreferences(shortcutHintMode: mode)
        )
        #expect(store.target(forPickerShortcutInput: "1", modifiers: [])?.id == "com.example.browser")
    }

    @Test("numeric shortcuts reject unavailable or invalid input")
    func numericShortcutsRejectInvalidInput() throws {
        let browser = makeBrowser(identifier: "com.example.browser", name: "Browser")
        for browsers in [[browser], []] {
            let store = try BrowserPickerStore(destination: IncomingURL("https://example.com"), browsers: browsers)
            for input in ["0", "2", "9", "10", "١", "５", ""] {
                #expect(store.target(forPickerShortcutInput: input, modifiers: []) == nil)
            }
            for modifiers in [EventModifiers.command, .option, .control, .shift] {
                #expect(store.target(forPickerShortcutInput: "1", modifiers: modifiers) == nil)
            }
        }
    }

    @Test("selects the first browser initially")
    func selectsFirstBrowser() throws {
        let browsers = [
            makeBrowser(
                identifier: "com.example.one",
                name: "One"
            ),
            makeBrowser(
                identifier: "com.example.two",
                name: "Two"
            ),
        ]
        let store = try BrowserPickerStore(
            destination: IncomingURL("https://example.com"),
            browsers: browsers
        )

        #expect(store.selectedIndex == 0)
        #expect(store.selectedBrowser == browsers[0])
    }

    @Test("has no selection when no browser is available")
    func handlesEmptyBrowserList() throws {
        let store = try BrowserPickerStore(
            destination: IncomingURL("https://example.com"),
            browsers: []
        )

        store.moveSelection(by: 1)

        #expect(store.selectedIndex == nil)
        #expect(store.selectedBrowser == nil)
    }

    @Test("wraps keyboard selection in both directions")
    func wrapsSelection() throws {
        let browsers = [
            makeBrowser(
                identifier: "com.example.one",
                name: "One"
            ),
            makeBrowser(
                identifier: "com.example.two",
                name: "Two"
            ),
            makeBrowser(
                identifier: "com.example.three",
                name: "Three"
            ),
        ]
        let store = try BrowserPickerStore(
            destination: IncomingURL("https://example.com"),
            browsers: browsers
        )

        store.moveSelection(by: -1)
        #expect(store.selectedIndex == 2)

        store.moveSelection(by: 1)
        #expect(store.selectedIndex == 0)

        store.moveSelection(by: 4)
        #expect(store.selectedIndex == 1)
    }

    @Test("ignores an out-of-bounds direct selection")
    func ignoresInvalidSelection() throws {
        let store = try BrowserPickerStore(
            destination: IncomingURL("https://example.com"),
            browsers: [
                makeBrowser(
                    identifier: "com.example.browser",
                    name: "Browser"
                ),
            ]
        )

        store.select(index: 9)

        #expect(store.selectedIndex == 0)
    }

    private func makeBrowser(
        identifier: String,
        name: String
    ) -> BrowserApplication {
        BrowserApplication(
            browser: Browser(
                bundleIdentifier: identifier,
                displayName: name
            ),
            applicationURL: URL(
                fileURLWithPath: "/Applications/\(name).app"
            ),
            icon: NSImage(
                size: NSSize(
                    width: 32,
                    height: 32
                )
            )
        )
    }
}
