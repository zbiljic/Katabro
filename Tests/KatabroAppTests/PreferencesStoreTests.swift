import AppKit
@testable import Katabro
import KatabroCore
import Testing

// The suite covers the complete aggregate preference contract in one fixture namespace.
// swiftlint:disable file_length type_body_length
@MainActor
@Suite("App preferences")
struct PreferencesStoreTests {
    @Test("legacy payloads receive picker presentation defaults")
    func pickerPresentationLegacyDefaults() throws {
        let decoded = try JSONDecoder().decode(
            AppPreferences.self,
            from: Data(#"{"browserOrder":["preserved.browser"]}"#.utf8)
        )

        #expect(decoded.browserOrder == ["preserved.browser"])
        #expect(decoded.pickerPreferences == BrowserPickerPreferences())
    }

    @Test("picker presentation round trips and clamps visible choices")
    func pickerPresentationRoundTrip() throws {
        let preferences = AppPreferences(
            hiddenBrowserIdentifiers: ["hidden.browser"],
            pickerPreferences: BrowserPickerPreferences(
                orientation: .horizontal,
                verticalWidth: .compact,
                visibleChoiceCount: 99,
                destinationDisplay: .fullURL,
                shortcutHintMode: .lettersOnly,
                horizontalLabelMode: .all,
                showsRememberChoice: false
            )
        )
        let decoded = try JSONDecoder().decode(
            AppPreferences.self,
            from: JSONEncoder().encode(preferences)
        )

        #expect(decoded == preferences)
        #expect(decoded.pickerPreferences.visibleChoiceCount == 8)
        #expect(decoded.hiddenBrowserIdentifiers == ["hidden.browser"])
    }

    @Test(
        "vertical width defaults independently for missing, malformed, and unknown values",
        arguments: [
            "",
            ",\"verticalWidth\":280",
            ",\"verticalWidth\":\"wide\"",
        ]
    )
    func verticalWidthLossTolerance(verticalWidthField: String) throws {
        let json = """
        {
          "browserOrder": ["preserved.browser"],
          "pickerPreferences": {
            "orientation": "horizontal",
            "visibleChoiceCount": 7,
            "destinationDisplay": "fullURL",
            "shortcutHintMode": "numbersOnly",
            "horizontalLabelMode": "all",
            "showsRememberChoice": false\(verticalWidthField)
          }
        }
        """
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data(json.utf8))

        #expect(decoded.browserOrder == ["preserved.browser"])
        #expect(decoded.pickerPreferences.verticalWidth == .standard)
        #expect(decoded.pickerPreferences.orientation == .horizontal)
        #expect(decoded.pickerPreferences.visibleChoiceCount == 7)
        #expect(decoded.pickerPreferences.destinationDisplay == .fullURL)
        #expect(decoded.pickerPreferences.shortcutHintMode == .numbersOnly)
        #expect(decoded.pickerPreferences.horizontalLabelMode == .all)
        #expect(!decoded.pickerPreferences.showsRememberChoice)
    }

    @Test(
        "malformed picker presentation fields fall back independently",
        arguments: [
            "orientation",
            "verticalWidth",
            "visibleChoiceCount",
            "destinationDisplay",
            "shortcutHintMode",
            "horizontalLabelMode",
            "showsRememberChoice",
        ]
    )
    func malformedPickerPresentationField(field: String) throws {
        let malformedValue = switch field {
        case "visibleChoiceCount": #""many""#
        case "showsRememberChoice": #""yes""#
        default: #""unknown""#
        }
        let validFields = [
            "orientation": #""horizontal""#,
            "verticalWidth": #""compact""#,
            "visibleChoiceCount": "7",
            "destinationDisplay": #""fullURL""#,
            "shortcutHintMode": #""numbersOnly""#,
            "horizontalLabelMode": #""all""#,
            "showsRememberChoice": "false",
        ]
        let pickerJSON = BrowserPickerPreferenceField.allCases
            .map { candidate in
                let value = candidate.rawValue == field
                    ? malformedValue
                    : validFields[candidate.rawValue, default: "null"]
                return "\"\(candidate.rawValue)\":\(value)"
            }
            .joined(separator: ",")
        let data = Data(
            "{\"browserOrder\":[\"preserved.browser\"],\"hiddenBrowserIdentifiers\":[\"hidden.browser\"],\"hasCompletedOnboarding\":true,\"pickerPreferences\":{\(pickerJSON)}}"
                .utf8
        )
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
        let picker = decoded.pickerPreferences

        #expect(picker.orientation == (field == "orientation" ? .vertical : .horizontal))
        #expect(picker.verticalWidth == (field == "verticalWidth" ? .standard : .compact))
        #expect(picker.visibleChoiceCount == (field == "visibleChoiceCount" ? 5 : 7))
        #expect(picker.destinationDisplay == (field == "destinationDisplay" ? .domain : .fullURL))
        #expect(picker.shortcutHintMode == (field == "shortcutHintMode" ? .all : .numbersOnly))
        #expect(picker.horizontalLabelMode == (field == "horizontalLabelMode" ? .selectedOnly : .all))
        #expect(picker.showsRememberChoice == (field == "showsRememberChoice"))
        #expect(decoded.browserOrder == ["preserved.browser"])
        #expect(decoded.hiddenBrowserIdentifiers == ["hidden.browser"])
        #expect(decoded.hasCompletedOnboarding)
    }

    @Test(
        "decoded visible choice boundaries clamp",
        arguments: [
            (2, 3),
            (9, 8),
        ]
    )
    func decodedVisibleChoiceBoundary(input: Int, expected: Int) throws {
        let data = Data("{\"pickerPreferences\":{\"visibleChoiceCount\":\(input)}}".utf8)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
        #expect(decoded.pickerPreferences.visibleChoiceCount == expected)
    }

    @Test("picker presentation mutations save locally once and never enter the sync snapshot")
    func pickerPresentationMutationIsLocalOnly() {
        var saves: [AppPreferences] = []
        let store = PreferencesStore(initialPreferences: AppPreferences()) { saves.append($0) }
        let updated = BrowserPickerPreferences(
            orientation: .horizontal,
            verticalWidth: .compact,
            visibleChoiceCount: 3,
            destinationDisplay: .hidden,
            shortcutHintMode: .hidden,
            horizontalLabelMode: .all,
            showsRememberChoice: false
        )

        #expect(store.setPickerPreferences(updated))
        #expect(!store.setPickerPreferences(updated))
        #expect(saves.count == 1)
        #expect(store.pickerPreferences == updated)
        #expect(store.browserSettingsSnapshot() == BrowserSettingsSnapshot(
            browserOrder: [],
            pickerShortcuts: [:],
            exactHostRoutingRules: []
        ))
    }

    @Test("picker presentation mutations write neither iCloud nor Folder transports")
    func pickerPresentationMutationSkipsTransports() {
        let cloudStore = PreferencesCloudStoreSpy()
        let cloudClient = ICloudPreferencesClient(
            store: cloudStore,
            notificationCenter: NotificationCenter()
        )
        let cloudPreferences = PreferencesStore(
            initialSyncStatus: .available,
            iCloudClient: cloudClient
        )
        #expect(cloudPreferences.setPickerPreferences(BrowserPickerPreferences(
            orientation: .horizontal,
            verticalWidth: .compact
        )))
        #expect(cloudStore.writes.isEmpty)

        let sharedSnapshot = BrowserSettingsSnapshot(
            browserOrder: [],
            pickerShortcuts: [:],
            exactHostRoutingRules: []
        )
        var folderWrites = 0
        let folderClient = FilePreferencesClient(
            injectedRead: { .snapshot(sharedSnapshot, bytes: Data("snapshot".utf8)) },
            injectedWrite: { _ in
                folderWrites += 1
                return true
            },
            displayName: "Provider"
        )
        let folderPreferences = PreferencesStore(syncMethod: .folder)
        #expect(folderPreferences.configureFolderSync(client: folderClient, displayName: "Provider"))
        folderWrites = 0
        #expect(folderPreferences.setPickerPreferences(BrowserPickerPreferences(
            verticalWidth: .compact,
            destinationDisplay: .hidden
        )))
        #expect(folderWrites == 0)
    }

    @Test(
        "validates and normalizes picker shortcut letters",
        arguments: [
            ("a", "A"),
            ("z", "Z"),
            ("A", "A"),
            ("Z", "Z"),
        ]
    )
    func validatesPickerShortcut(
        input: String,
        expected: String
    ) throws {
        let shortcut = try #require(PickerShortcut(input))

        #expect(shortcut.rawValue == expected)
        #expect(shortcut.displayValue == expected)
    }

    @Test(
        "rejects invalid picker shortcut values",
        arguments: [
            "",
            "aa",
            "1",
            "-",
            " ",
            "é",
            "e\u{301}",
        ]
    )
    func rejectsInvalidPickerShortcut(
        input: String
    ) {
        #expect(PickerShortcut(input) == nil)
    }

    @Test("replaces picker shortcuts with the newly typed letter")
    func replacesPickerShortcutFromEditedText() {
        let testCases = [
            ShortcutEditCase(currentValue: "", editedValue: "s", expected: "S"),
            ShortcutEditCase(currentValue: "S", editedValue: "Sc", expected: "C"),
            ShortcutEditCase(currentValue: "S", editedValue: "cS", expected: "C"),
            ShortcutEditCase(currentValue: "S", editedValue: "Ss", expected: "S"),
            ShortcutEditCase(currentValue: "S", editedValue: "S1", expected: nil),
            ShortcutEditCase(currentValue: "", editedValue: "xy", expected: nil),
        ]

        for testCase in testCases {
            #expect(
                PickerShortcut.replacement(
                    in: testCase.editedValue,
                    replacing: testCase.currentValue
                )?.rawValue == testCase.expected
            )
        }
    }

    @Test("picker shortcut survives a Codable round trip")
    func pickerShortcutCodableRoundTrip() throws {
        let shortcut = try #require(PickerShortcut("S"))
        let data = try JSONEncoder().encode(shortcut)
        let decoded = try JSONDecoder().decode(
            PickerShortcut.self,
            from: data
        )

        #expect(decoded == shortcut)
        #expect(String(data: data, encoding: .utf8) == "\"S\"")
    }

    @Test("decodes missing and malformed picker shortcut data safely")
    func decodesPickerShortcutCompatibility() throws {
        let legacyData = Data(
            """
            {"browserOrder":["com.example.browser"]}
            """.utf8
        )
        let malformedData = Data(
            """
            {"pickerShortcuts":{"valid.browser":"s","digit.browser":"1","long.browser":"xy"}}
            """.utf8
        )
        let wrongShapeData = Data(
            """
            {"browserOrder":["preserved.browser"],"pickerShortcuts":["invalid"]}
            """.utf8
        )

        let legacy = try JSONDecoder().decode(
            AppPreferences.self,
            from: legacyData
        )
        let malformed = try JSONDecoder().decode(
            AppPreferences.self,
            from: malformedData
        )
        let wrongShape = try JSONDecoder().decode(
            AppPreferences.self,
            from: wrongShapeData
        )

        #expect(legacy.pickerShortcuts.isEmpty)
        #expect(malformed.pickerShortcuts == ["valid.browser": PickerShortcut("s")])
        #expect(wrongShape.browserOrder == ["preserved.browser"])
        #expect(wrongShape.pickerShortcuts.isEmpty)
    }

    @Test("normalizes identifiers and resolves duplicate letters deterministically")
    func normalizesPickerShortcutAssignments() throws {
        let shortcut = try #require(PickerShortcut("S"))
        let store = try PreferencesStore(
            initialPreferences: AppPreferences(
                pickerShortcuts: [
                    " z.browser ": shortcut,
                    "A.browser": shortcut,
                    "": #require(PickerShortcut("x")),
                ]
            )
        )

        #expect(store.pickerShortcuts == ["a.browser": shortcut])
        #expect(store.pickerShortcut(for: " A.BROWSER ") == shortcut)
    }

    @Test("transfers and clears picker shortcuts atomically without no-op saves")
    func transfersAndClearsPickerShortcuts() throws {
        let shortcut = try #require(PickerShortcut("s"))
        var saves: [AppPreferences] = []
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: ["one", "two"],
                hiddenBrowserIdentifiers: ["two"],
                pickerShortcuts: ["one": shortcut],
                hasCompletedOnboarding: true
            )
        ) { saves.append($0) }

        #expect(!store.setPickerShortcut(shortcut, for: " ONE "))
        #expect(saves.isEmpty)

        #expect(store.setPickerShortcut(shortcut, for: "TWO"))
        #expect(store.pickerShortcuts == ["two": shortcut])
        #expect(store.hiddenBrowserIdentifiers == ["two"])
        #expect(store.browserOrder == ["one", "two"])
        #expect(store.hasCompletedOnboarding)
        #expect(saves.count == 1)

        #expect(store.setPickerShortcut(nil, for: "two"))
        #expect(store.pickerShortcuts.isEmpty)
        #expect(saves.count == 2)
        #expect(!store.setPickerShortcut(nil, for: "two"))
        #expect(saves.count == 2)
    }

    @Test("picker shortcut changes write their iCloud key when available")
    func syncsPickerShortcuts() throws {
        let input = "O"
        let shortcut = try #require(PickerShortcut(input))
        let cloudStore = PreferencesCloudStoreSpy()
        var saves: [AppPreferences] = []
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: ["one"]
            ),
            initialSyncStatus: .available,
            iCloudClient: ICloudPreferencesClient(
                store: cloudStore,
                notificationCenter: NotificationCenter()
            )
        ) { saves.append($0) }

        #expect(
            store.setPickerShortcut(
                shortcut,
                for: "one"
            )
        )

        #expect(saves.count == 1)
        #expect(saves[0].browserOrder == ["one"])
        #expect(cloudStore.writes.count == 1)
        #expect(cloudStore.writes.first?.key == ICloudPreferencesClient.pickerShortcutsKey)
        #expect(cloudStore.writes.first?.value as? [String: String] == ["one": "O"])
    }

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

extension PreferencesStoreTests {
    @Test("legacy and lossy decoding preserve valid preferences")
    func decodesExactHostRulesLossily() throws {
        let data = Data(
            """
            {
              "browserOrder": ["com.example.browser"],
              "exactHostRoutingRules": [
                {"host":"Example.com.","targetIdentifier":"first"},
                {"host":"","targetIdentifier":"invalid"},
                {"host":"other.example","targetIdentifier":"second"}
              ]
            }
            """.utf8
        )
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: data)

        #expect(preferences.browserOrder == ["com.example.browser"])
        #expect(preferences.exactHostRoutingRules.map(\.host) == [
            "example.com",
            "other.example",
        ])
    }

    @Test("normalizes duplicates and keeps the latest target in first position")
    func normalizesExactHostRules() throws {
        let store = try PreferencesStore(
            initialPreferences: AppPreferences(
                exactHostRoutingRules: [
                    #require(ExactHostRoutingRule(host: "Example.com", targetIdentifier: "old")),
                    #require(ExactHostRoutingRule(host: "other.example", targetIdentifier: "other")),
                    #require(ExactHostRoutingRule(host: "example.com.", targetIdentifier: "new")),
                ]
            )
        )

        #expect(store.exactHostRoutingRules.map(\.host) == ["example.com", "other.example"])
        #expect(store.exactHostRoutingRules.map(\.targetIdentifier) == ["new", "other"])
    }

    @Test("adds, replaces, removes, and clears rules with no-op saves")
    func mutatesExactHostRulesLocally() throws {
        var saves: [AppPreferences] = []
        let cloudStore = PreferencesCloudStoreSpy()
        let store = PreferencesStore(
            initialPreferences: AppPreferences(hasCompletedOnboarding: true),
            initialSyncStatus: .available,
            iCloudClient: ICloudPreferencesClient(
                store: cloudStore,
                notificationCenter: NotificationCenter()
            )
        ) { saves.append($0) }
        let destination = try IncomingURL("https://Example.com/path?q=secret")

        #expect(store.setExactHostRoutingRule(for: destination, targetIdentifier: "first"))
        #expect(!store.setExactHostRoutingRule(for: destination, targetIdentifier: "first"))
        #expect(store.setExactHostRoutingRule(for: destination, targetIdentifier: "Second Case "))
        #expect(store.exactHostRoutingRules.map(\.host) == ["example.com"])
        #expect(store.exactHostRoutingRules.first?.targetIdentifier == "Second Case ")
        #expect(store.hasCompletedOnboarding)
        #expect(store.removeExactHostRoutingRule(host: " EXAMPLE.COM. "))
        #expect(!store.removeExactHostRoutingRule(host: "example.com"))
        #expect(!store.removeAllExactHostRoutingRules())
        #expect(saves.count == 3)
        #expect(cloudStore.writes.isEmpty)
    }

    @Test("rejects exact-host rules for file destinations")
    func rejectsFileExactHostRules() throws {
        let store = PreferencesStore()
        let destination = try IncomingURL("file://localhost/tmp/example.html")

        #expect(!store.setExactHostRoutingRule(for: destination, targetIdentifier: "browser"))
        #expect(store.exactHostRoutingRules.isEmpty)
    }
}

struct ShortcutEditCase: Sendable {
    let currentValue: String
    let editedValue: String
    let expected: String?
}

private enum BrowserPickerPreferenceField: String, CaseIterable {
    case orientation
    case verticalWidth
    case visibleChoiceCount
    case destinationDisplay
    case shortcutHintMode
    case horizontalLabelMode
    case showsRememberChoice
}

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

// swiftlint:enable file_length type_body_length
