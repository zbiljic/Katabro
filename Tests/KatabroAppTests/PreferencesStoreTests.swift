import AppKit
@testable import Katabro
import KatabroCore
import Testing

// The suite covers the complete aggregate preference contract in one fixture namespace.
// swiftlint:disable type_body_length
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
                ],
                hiddenBrowserIdentifiers: ["two"]
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
        #expect(store.hiddenBrowserIdentifiers == ["two"])
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
        #expect(preferences.hiddenBrowserIdentifiers.isEmpty)
        #expect(!preferences.hasCompletedOnboarding)
    }

    @Test("normalizes hidden identifiers case-insensitively")
    func normalizesHiddenIdentifiers() {
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                hiddenBrowserIdentifiers: [
                    " com.example.Browser ",
                    "COM.EXAMPLE.BROWSER",
                    "",
                    "\n",
                    "com.example.other",
                ]
            )
        )

        #expect(
            store.hiddenBrowserIdentifiers == [
                "com.example.Browser",
                "com.example.other",
            ]
        )
    }

    @Test("hides one browser while retaining Settings order")
    func hidesBrowserWithoutFilteringSettingsOrder() {
        var savedPreferences: [AppPreferences] = []
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: [
                    "com.example.second",
                    "com.example.first",
                ]
            )
        ) { savedPreferences.append($0) }
        let first = makeBrowser(
            identifier: "com.example.first",
            name: "First"
        )
        let second = makeBrowser(
            identifier: "com.example.second",
            name: "Second"
        )

        let changed = store.setBrowserShown(
            " COM.EXAMPLE.SECOND ",
            shown: false,
            among: [
                "com.example.first",
                "com.example.second",
            ]
        )

        #expect(changed)
        #expect(store.hiddenBrowserIdentifiers == ["com.example.second"])
        #expect(
            store.orderedBrowsers([first, second]).map(\.browser.bundleIdentifier) == [
                "com.example.second",
                "com.example.first",
            ]
        )
        #expect(
            store.effectiveVisibleBrowsers([first, second]) == [first]
        )
        #expect(savedPreferences == [store.preferences])
    }

    @Test("newly discovered browser is shown by default")
    func showsNewBrowserByDefault() {
        let hidden = makeBrowser(
            identifier: "com.example.hidden",
            name: "Hidden"
        )
        let newlyInstalled = makeBrowser(
            identifier: "com.example.new",
            name: "New"
        )
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                hiddenBrowserIdentifiers: ["COM.EXAMPLE.HIDDEN"]
            )
        )

        #expect(
            store.effectiveVisibleBrowsers([hidden, newlyInstalled]) == [newlyInstalled]
        )
        #expect(
            store.isBrowserShown(
                "com.example.new",
                among: [
                    "com.example.hidden",
                    "com.example.new",
                ]
            )
        )
    }

    @Test("effective visibility preserves the supplied browser order")
    func preservesSuppliedVisibilityOrder() {
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
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: [
                    "com.example.first",
                    "com.example.second",
                    "com.example.third",
                ],
                hiddenBrowserIdentifiers: ["com.example.second"]
            )
        )

        #expect(
            store.effectiveVisibleBrowsers([third, second, first]) == [third, first]
        )
    }

    @Test("refuses to hide the last effective browser without saving")
    func refusesLastEffectiveHide() {
        var savedPreferences: [AppPreferences] = []
        let store = PreferencesStore { savedPreferences.append($0) }

        let changed = store.setBrowserShown(
            "com.example.only",
            shown: false,
            among: ["com.example.only"]
        )

        #expect(!changed)
        #expect(store.hiddenBrowserIdentifiers.isEmpty)
        #expect(savedPreferences.isEmpty)
    }

    @Test("all-hidden external state falls back without writing")
    func fallsBackWhenAllDiscoveredBrowsersAreHidden() {
        var savedPreferences: [AppPreferences] = []
        let first = makeBrowser(
            identifier: "com.example.first",
            name: "First"
        )
        let second = makeBrowser(
            identifier: "com.example.second",
            name: "Second"
        )
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: [
                    "com.example.second",
                    "com.example.first",
                ],
                hiddenBrowserIdentifiers: [
                    "com.example.first",
                    "com.example.second",
                ]
            )
        ) { savedPreferences.append($0) }

        let alreadyOrderedBrowsers = [second, first]
        let visibleBrowsers = store.effectiveVisibleBrowsers(alreadyOrderedBrowsers)

        #expect(visibleBrowsers == [second])
        #expect(
            store.isBrowserShown(
                "com.example.second",
                among: [
                    "com.example.second",
                    "com.example.first",
                ]
            )
        )
        #expect(savedPreferences.isEmpty)
    }

    @Test("Show All changes only local visibility preferences")
    func showsAllWithoutChangingOtherPreferencesOrCloud() {
        var savedPreferences: [AppPreferences] = []
        let cloudStore = PreferencesCloudStoreSpy()
        let cloudClient = ICloudPreferencesClient(
            store: cloudStore,
            notificationCenter: NotificationCenter()
        )
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: ["two", "one"],
                hiddenBrowserIdentifiers: ["one"],
                hasCompletedOnboarding: true
            ),
            initialSyncStatus: .available,
            iCloudClient: cloudClient
        ) { savedPreferences.append($0) }

        let changed = store.showAllBrowsers()

        #expect(changed)
        #expect(store.hiddenBrowserIdentifiers.isEmpty)
        #expect(store.browserOrder == ["two", "one"])
        #expect(store.hasCompletedOnboarding)
        #expect(savedPreferences == [store.preferences])
        #expect(cloudStore.writes.isEmpty)
    }

    @Test("visibility changes save locally and never write to cloud")
    func keepsVisibilityLocal() {
        var savedPreferences: [AppPreferences] = []
        let cloudStore = PreferencesCloudStoreSpy()
        let store = PreferencesStore(
            initialSyncStatus: .available,
            iCloudClient: ICloudPreferencesClient(
                store: cloudStore,
                notificationCenter: NotificationCenter()
            )
        ) { savedPreferences.append($0) }

        let changed = store.setBrowserShown(
            "com.example.second",
            shown: false,
            among: [
                "com.example.first",
                "com.example.second",
            ]
        )

        #expect(changed)
        #expect(savedPreferences.map(\.hiddenBrowserIdentifiers) == [["com.example.second"]])
        #expect(cloudStore.writes.isEmpty)
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

// swiftlint:enable type_body_length

@MainActor
private final class PreferencesCloudStoreSpy: ICloudKeyValueStoring {
    struct Write {
        let key: String
        let value: Any?
    }

    var writes: [Write] = []

    func object(forKey _: String) -> Any? {
        nil
    }

    func set(_ anObject: Any?, forKey aKey: String) {
        writes.append(
            Write(
                key: aKey,
                value: anObject
            )
        )
    }

    func synchronize() -> Bool {
        true
    }
}
