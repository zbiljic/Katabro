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
                "com.example.missing",
            ]
        )
        #expect(savedPreferences.isEmpty)
    }

    @Test("visible reorder preserves browsers unavailable on this Mac")
    func preservesUnavailableBrowserOrder() {
        var savedPreferences: [AppPreferences] = []
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: [
                    "com.google.Chrome",
                    "org.mozilla.firefox",
                    "com.apple.Safari",
                ]
            )
        ) { preferences in
            savedPreferences.append(preferences)
        }

        store.setVisibleBrowserOrder(
            [
                "com.apple.Safari",
                "com.google.Chrome",
            ]
        )

        #expect(
            store.browserOrder == [
                "com.apple.Safari",
                "org.mozilla.firefox",
                "com.google.Chrome",
            ]
        )
        #expect(savedPreferences == [store.preferences])
    }

    @Test("new visible browsers append after preserved stored slots")
    func appendsNewVisibleBrowser() {
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: [
                    "com.google.Chrome",
                    "org.mozilla.firefox",
                ]
            )
        )

        store.setVisibleBrowserOrder(
            [
                "com.google.Chrome",
                "com.apple.Safari",
            ]
        )

        #expect(
            store.browserOrder == [
                "com.google.Chrome",
                "org.mozilla.firefox",
                "com.apple.Safari",
            ]
        )
    }

    @Test("normalizes duplicate and empty identifiers")
    func normalizesIdentifiers() {
        let store = PreferencesStore()

        store.setVisibleBrowserOrder(
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
        var savedPreferences: [AppPreferences] = []
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: [
                    "one",
                    "two",
                    "three",
                ]
            )
        ) { preferences in
            savedPreferences.append(preferences)
        }

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
        #expect(savedPreferences.last?.browserOrder.isEmpty == true)
    }

    @Test("completing onboarding preserves browser order")
    func completesOnboarding() {
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: ["com.example.browser"]
            )
        )

        store.completeOnboarding()

        #expect(store.hasCompletedOnboarding)
        #expect(store.browserOrder == ["com.example.browser"])
    }

    @Test("decodes preferences saved before onboarding was added")
    func decodesLegacyPreferences() throws {
        let data = Data(
            """
            {"browserOrder":["com.example.browser"]}
            """.utf8
        )

        let preferences = try JSONDecoder().decode(
            AppPreferences.self,
            from: data
        )

        #expect(preferences.browserOrder == ["com.example.browser"])
        #expect(!preferences.hasCompletedOnboarding)
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
