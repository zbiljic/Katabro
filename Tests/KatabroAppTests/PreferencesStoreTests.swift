import AppKit
@testable import Katabro
import KatabroCore
import Testing

@MainActor
@Suite("App preferences")
struct PreferencesStoreTests {
    @Test("restores known browser order and appends new browsers")
    func reconcilesBrowserOrder() {
        var savedPreferences: [AppPreferences] = []
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: [
                    "com.example.second",
                    "com.example.missing",
                ]
            )
        ) { preferences in
            savedPreferences.append(preferences)
        }
        let first = makeBrowser(
            identifier: "com.example.first",
            name: "First"
        )
        let second = makeBrowser(
            identifier: "com.example.second",
            name: "Second"
        )
        let third = makeBrowser(
            identifier: "com.example.third",
            name: "Third"
        )

        let orderedBrowsers = store.orderedBrowsers(
            [
                first,
                second,
                third,
            ]
        )

        #expect(
            orderedBrowsers.map(\.browser.bundleIdentifier) == [
                "com.example.second",
                "com.example.first",
                "com.example.third",
            ]
        )
        #expect(
            store.browserOrder == [
                "com.example.second",
                "com.example.first",
                "com.example.third",
            ]
        )
        #expect(savedPreferences.last == store.preferences)
    }

    @Test("normalizes duplicate and empty identifiers")
    func normalizesIdentifiers() {
        let store = PreferencesStore()

        store.setBrowserOrder(
            [
                " com.example.Browser ",
                "COM.EXAMPLE.BROWSER",
                "",
                "com.example.other",
            ]
        )

        #expect(
            store.browserOrder == [
                "com.example.Browser",
                "com.example.other",
            ]
        )
    }

    @Test("moves and resets browser order")
    func movesAndResetsOrder() {
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: [
                    "one",
                    "two",
                    "three",
                ]
            )
        )

        store.moveBrowser(
            from: IndexSet(integer: 0),
            to: 3
        )
        #expect(
            store.browserOrder == [
                "two",
                "three",
                "one",
            ]
        )

        store.resetBrowserOrder()
        #expect(store.browserOrder.isEmpty)
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
