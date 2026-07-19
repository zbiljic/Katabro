import AppKit
@testable import Katabro
import KatabroCore
import Testing

@MainActor
@Suite("Browser picker state")
struct BrowserPickerStoreTests {
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
