import Foundation
@testable import Katabro
import Testing

// The suite keeps the complete multi-key synchronization contract in one harness.
// swiftlint:disable file_length type_body_length
@MainActor
@Suite("iCloud preference sync")
struct PreferencesStoreICloudTests {
    @Test("cloud order wins without changing local onboarding")
    func appliesCloudOrderAtStartup() {
        let harness = PreferencesCloudHarness(
            cloudValue: ["cloud.second", "cloud.first"]
        )
        var saves: [AppPreferences] = []
        let store = harness.makeStore(
            preferences: AppPreferences(
                browserOrder: ["local.browser"],
                hasCompletedOnboarding: true
            )
        ) { saves.append($0) }

        store.startICloudSync()

        #expect(store.browserOrder == ["cloud.second", "cloud.first"])
        #expect(store.hasCompletedOnboarding)
        #expect(store.iCloudSyncStatus == .available)
        #expect(saves == [store.preferences])
        #expect(harness.keyValueStore.writes.isEmpty)
    }

    @Test("cloud shortcuts win and normalize at startup")
    func appliesCloudShortcutsAtStartup() throws {
        let harness = PreferencesCloudHarness(
            cloudValue: ["browser.one", "browser.two"],
            cloudShortcuts: [
                " BROWSER.TWO ": "a",
                "browser.one": "S",
            ]
        )
        var saves: [AppPreferences] = []
        let store = try harness.makeStore(
            preferences: AppPreferences(
                browserOrder: ["browser.one", "browser.two"],
                pickerShortcuts: [
                    "local.browser": #require(PickerShortcut("L")),
                ]
            )
        ) { saves.append($0) }

        store.startICloudSync()

        #expect(try store.pickerShortcuts == [
            "browser.one": #require(PickerShortcut("S")),
            "browser.two": #require(PickerShortcut("A")),
        ])
        #expect(store.iCloudSyncStatus == .available)
        #expect(saves == [store.preferences])
        #expect(harness.keyValueStore.writes.isEmpty)
    }

    @Test("empty cloud order clears custom order and preserves onboarding")
    func appliesEmptyCloudOrder() {
        let harness = PreferencesCloudHarness(
            cloudValue: [String]()
        )
        var saves: [AppPreferences] = []
        let store = harness.makeStore(
            preferences: AppPreferences(
                browserOrder: ["local.browser"],
                hasCompletedOnboarding: true
            )
        ) { saves.append($0) }

        store.startICloudSync()

        #expect(store.browserOrder.isEmpty)
        #expect(store.hasCompletedOnboarding)
        #expect(saves.count == 1)
        #expect(harness.keyValueStore.writes.isEmpty)
    }

    @Test("missing cloud order seeds normalized local order once")
    func seedsMissingCloudOrder() {
        let harness = PreferencesCloudHarness()
        var saves: [AppPreferences] = []
        let store = harness.makeStore(
            preferences: AppPreferences(
                browserOrder: [" local.browser ", "LOCAL.BROWSER"]
            )
        ) { saves.append($0) }

        store.startICloudSync()

        #expect(store.browserOrder == ["local.browser"])
        #expect(store.iCloudSyncStatus == .available)
        #expect(saves.count == 1)
        #expect(harness.writtenOrders == [["local.browser"]])
        #expect(harness.keyValueStore.synchronizeCallCount == 1)
    }

    @Test("missing cloud shortcuts seed normalized local assignments once")
    func seedsMissingCloudShortcuts() throws {
        let harness = PreferencesCloudHarness(
            cloudValue: ["browser.one"],
            cloudShortcuts: nil
        )
        let store = try harness.makeStore(
            preferences: AppPreferences(
                pickerShortcuts: [
                    " BROWSER.ONE ": #require(PickerShortcut("s")),
                ]
            )
        ) { _ in }

        store.startICloudSync()

        #expect(try store.pickerShortcuts == [
            "browser.one": #require(PickerShortcut("S")),
        ])
        #expect(harness.writtenShortcuts == [["browser.one": "S"]])
        #expect(store.iCloudSyncStatus == .available)
    }

    @Test("invalid cloud data remains untouched while local updates work")
    func retainsInvalidCloudData() {
        let harness = PreferencesCloudHarness(
            cloudValue: "invalid"
        )
        var saves: [AppPreferences] = []
        let store = harness.makeStore(
            preferences: AppPreferences(browserOrder: ["local.browser"])
        ) { saves.append($0) }

        store.startICloudSync()
        store.setBrowserOrder(["local.changed"])

        #expect(store.browserOrder == ["local.changed"])
        #expect(store.iCloudSyncStatus == .invalidCloudValue)
        #expect(saves.count == 1)
        #expect(harness.keyValueStore.writes.isEmpty)
        #expect(
            harness.keyValueStore.values[ICloudPreferencesClient.browserOrderKey]
                as? String == "invalid"
        )
    }

    @Test("local reorder writes local and cloud once")
    func uploadsLocalReorder() {
        let harness = PreferencesCloudHarness(
            cloudValue: ["one", "two"]
        )
        var saves: [AppPreferences] = []
        let store = harness.makeStore(
            preferences: AppPreferences(browserOrder: ["one", "two"])
        ) { saves.append($0) }
        store.startICloudSync()

        store.setVisibleBrowserOrder(["two", "one"])

        #expect(saves.map(\.browserOrder) == [["two", "one"]])
        #expect(harness.writtenOrders == [["two", "one"]])
        #expect(harness.keyValueStore.synchronizeCallCount == 1)
    }

    @Test("local shortcut changes write local and cloud once")
    func uploadsLocalShortcutChange() throws {
        let harness = PreferencesCloudHarness(
            cloudValue: ["browser.one"]
        )
        var saves: [AppPreferences] = []
        let store = harness.makeStore(
            preferences: AppPreferences(
                browserOrder: ["browser.one"]
            )
        ) { saves.append($0) }
        store.startICloudSync()
        let shortcut = try #require(PickerShortcut("S"))

        store.setPickerShortcut(
            shortcut,
            for: "browser.one"
        )

        #expect(try saves.map(\.pickerShortcuts) == [[
            "browser.one": #require(PickerShortcut("S")),
        ]])
        #expect(harness.writtenShortcuts == [["browser.one": "S"]])
    }

    @Test("remote changes update locally without echoing")
    func appliesRemoteChangesWithoutEcho() async {
        let harness = PreferencesCloudHarness(
            cloudValue: ["one"]
        )
        var saves: [AppPreferences] = []
        let store = harness.makeStore(
            preferences: AppPreferences(browserOrder: ["one"])
        ) { saves.append($0) }
        store.startICloudSync()

        harness.setCloudValue(["two", "one"])
        harness.post(
            reason: NSUbiquitousKeyValueStoreServerChange,
            keys: [ICloudPreferencesClient.browserOrderKey]
        )
        await Task.yield()

        #expect(store.browserOrder == ["two", "one"])
        #expect(saves.map(\.browserOrder) == [["two", "one"]])
        #expect(harness.keyValueStore.writes.isEmpty)
        #expect(store.iCloudSyncStatus == .available)
    }

    @Test("remote shortcut changes update locally without echoing")
    func appliesRemoteShortcutChangesWithoutEcho() async throws {
        let harness = PreferencesCloudHarness(
            cloudValue: ["browser.one"],
            cloudShortcuts: ["browser.one": "S"]
        )
        var saves: [AppPreferences] = []
        let store = try harness.makeStore(
            preferences: AppPreferences(
                browserOrder: ["browser.one"],
                pickerShortcuts: [
                    "browser.one": #require(PickerShortcut("S")),
                ]
            )
        ) { saves.append($0) }
        store.startICloudSync()

        harness.setCloudShortcuts(["browser.two": "c"])
        harness.post(
            reason: NSUbiquitousKeyValueStoreServerChange,
            keys: [ICloudPreferencesClient.pickerShortcutsKey]
        )
        await Task.yield()

        #expect(try store.pickerShortcuts == [
            "browser.two": #require(PickerShortcut("C")),
        ])
        #expect(try saves.map(\.pickerShortcuts) == [[
            "browser.two": #require(PickerShortcut("C")),
        ]])
        #expect(harness.keyValueStore.writes.isEmpty)
        #expect(store.iCloudSyncStatus == .available)
    }

    @Test("invalid cloud shortcuts retain local assignments")
    func retainsInvalidCloudShortcuts() throws {
        let harness = PreferencesCloudHarness(
            cloudValue: ["browser.one"],
            cloudShortcuts: ["browser.one": "1"]
        )
        let localShortcut = try #require(PickerShortcut("S"))
        let store = harness.makeStore(
            preferences: AppPreferences(
                pickerShortcuts: ["browser.one": localShortcut]
            )
        ) { _ in }

        store.startICloudSync()

        #expect(store.pickerShortcuts == ["browser.one": localShortcut])
        #expect(store.iCloudSyncStatus == .invalidCloudValue)
        #expect(harness.keyValueStore.writes.isEmpty)
    }

    @Test("irrelevant server changes are ignored")
    func ignoresIrrelevantServerChanges() async {
        let harness = PreferencesCloudHarness(
            cloudValue: ["one"]
        )
        var saves: [AppPreferences] = []
        let store = harness.makeStore(
            preferences: AppPreferences(browserOrder: ["one"])
        ) { saves.append($0) }
        store.startICloudSync()
        harness.setCloudValue(["two"])

        harness.post(
            reason: NSUbiquitousKeyValueStoreServerChange,
            keys: ["unrelated"]
        )
        await Task.yield()

        #expect(store.browserOrder == ["one"])
        #expect(saves.isEmpty)
    }

    @Test("missing remote values retain local state and do not echo", arguments: [
        NSUbiquitousKeyValueStoreServerChange,
        NSUbiquitousKeyValueStoreInitialSyncChange,
        NSUbiquitousKeyValueStoreAccountChange,
    ])
    func retainsLocalForMissingRemoteValue(reason: Int) async {
        let harness = PreferencesCloudHarness(
            cloudValue: ["local.browser"]
        )
        var saves: [AppPreferences] = []
        let store = harness.makeStore(
            preferences: AppPreferences(browserOrder: ["local.browser"])
        ) { saves.append($0) }
        store.startICloudSync()
        harness.removeCloudValue()

        harness.post(reason: reason)
        await Task.yield()

        #expect(store.browserOrder == ["local.browser"])
        #expect(store.iCloudSyncStatus == .available)
        #expect(saves.isEmpty)
        #expect(harness.keyValueStore.writes.isEmpty)
    }

    @Test("onboarding completion never writes to cloud")
    func keepsOnboardingLocal() {
        let harness = PreferencesCloudHarness(
            cloudValue: ["browser"]
        )
        var saves: [AppPreferences] = []
        let store = harness.makeStore(
            preferences: AppPreferences(browserOrder: ["browser"])
        ) { saves.append($0) }
        store.startICloudSync()

        store.completeOnboarding()

        #expect(store.hasCompletedOnboarding)
        #expect(saves.count == 1)
        #expect(harness.keyValueStore.writes.isEmpty)
    }

    @Test("failed startup and quota retain local behavior")
    func handlesUnavailableCloud() async {
        let harness = PreferencesCloudHarness(
            cloudValue: ["cloud.browser"],
            synchronizeResult: false
        )
        var saves: [AppPreferences] = []
        let store = harness.makeStore(
            preferences: AppPreferences(browserOrder: ["local.browser"])
        ) { saves.append($0) }
        store.startICloudSync()

        #expect(store.browserOrder == ["local.browser"])
        #expect(store.iCloudSyncStatus == .localOnly)

        harness.post(reason: NSUbiquitousKeyValueStoreQuotaViolationChange)
        await Task.yield()
        store.setBrowserOrder(["local.changed"])

        #expect(store.browserOrder == ["local.changed"])
        #expect(saves.count == 1)
        #expect(harness.keyValueStore.writes.isEmpty)
    }

    @Test("later valid cloud data recovers unavailable and invalid states", arguments: [
        false,
        true,
    ])
    func recoversCloudStatus(initiallyInvalid: Bool) async {
        let harness = PreferencesCloudHarness(
            cloudValue: initiallyInvalid ? "invalid" : ["cloud.browser"],
            synchronizeResult: initiallyInvalid
        )
        var saves: [AppPreferences] = []
        let store = harness.makeStore(
            preferences: AppPreferences(browserOrder: ["local.browser"])
        ) { saves.append($0) }
        store.startICloudSync()
        #expect(
            store.iCloudSyncStatus
                == (initiallyInvalid ? .invalidCloudValue : .localOnly)
        )

        harness.setCloudValue(["recovered.browser"])
        harness.post(
            reason: NSUbiquitousKeyValueStoreServerChange,
            keys: [ICloudPreferencesClient.browserOrderKey]
        )
        await Task.yield()

        #expect(store.browserOrder == ["recovered.browser"])
        #expect(store.iCloudSyncStatus == .available)
        #expect(harness.keyValueStore.writes.isEmpty)
    }
}

// swiftlint:enable type_body_length

@MainActor
private final class PreferencesCloudHarness {
    let keyValueStore = PreferencesKeyValueStore()
    let notificationCenter = NotificationCenter()
    let client: ICloudPreferencesClient

    var writtenOrders: [[String]] {
        keyValueStore.writes.compactMap { write in
            guard write.key == ICloudPreferencesClient.browserOrderKey else {
                return nil
            }

            return write.value as? [String]
        }
    }

    var writtenShortcuts: [[String: String]] {
        keyValueStore.writes.compactMap { write in
            guard write.key == ICloudPreferencesClient.pickerShortcutsKey else {
                return nil
            }

            return write.value as? [String: String]
        }
    }

    init(
        cloudValue: Any? = nil,
        cloudShortcuts: Any? = [String: String](),
        synchronizeResult: Bool = true
    ) {
        if let cloudValue {
            keyValueStore.values[ICloudPreferencesClient.browserOrderKey] = cloudValue
        }
        if let cloudShortcuts {
            keyValueStore.values[ICloudPreferencesClient.pickerShortcutsKey] = cloudShortcuts
        }
        keyValueStore.synchronizeResult = synchronizeResult
        client = ICloudPreferencesClient(
            store: keyValueStore,
            notificationCenter: notificationCenter
        )
    }

    func makeStore(
        preferences: AppPreferences,
        save: @escaping (AppPreferences) -> Void
    ) -> PreferencesStore {
        PreferencesStore(
            initialPreferences: preferences,
            iCloudClient: client,
            save: save
        )
    }

    func setCloudValue(_ value: Any) {
        keyValueStore.values[ICloudPreferencesClient.browserOrderKey] = value
    }

    func setCloudShortcuts(_ value: Any) {
        keyValueStore.values[ICloudPreferencesClient.pickerShortcutsKey] = value
    }

    func removeCloudValue() {
        keyValueStore.values.removeValue(
            forKey: ICloudPreferencesClient.browserOrderKey
        )
    }

    func post(
        reason: Int,
        keys: [String]? = nil
    ) {
        var userInfo: [AnyHashable: Any] = [
            NSUbiquitousKeyValueStoreChangeReasonKey: reason,
        ]

        if let keys {
            userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] = keys
        }

        notificationCenter.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: keyValueStore,
            userInfo: userInfo
        )
    }
}

@MainActor
private final class PreferencesKeyValueStore: ICloudKeyValueStoring {
    struct Write {
        let key: String
        let value: Any?
    }

    var values: [String: Any] = [:]
    var writes: [Write] = []
    var synchronizeCallCount = 0
    var synchronizeResult = true

    func object(forKey aKey: String) -> Any? {
        values[aKey]
    }

    func set(_ anObject: Any?, forKey aKey: String) {
        writes.append(
            Write(
                key: aKey,
                value: anObject
            )
        )

        if let anObject {
            values[aKey] = anObject
        } else {
            values.removeValue(forKey: aKey)
        }
    }

    func synchronize() -> Bool {
        synchronizeCallCount += 1
        return synchronizeResult
    }
}

// swiftlint:enable file_length
