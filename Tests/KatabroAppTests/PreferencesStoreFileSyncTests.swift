import Foundation
@testable import Katabro
import KatabroCore
import os
import Testing

// Folder lifecycle coverage intentionally lives with the transport contract.
// swiftlint:disable file_length
@MainActor
@Suite("Folder preference sync")
struct PreferencesStoreFileSyncTests { // swiftlint:disable:this type_body_length
    @Test("defaults to This Mac without iCloud and iCloud with a client")
    func startupDefaults() {
        #expect(PreferencesStore().syncMethod == .thisMac)
        let client = ICloudPreferencesClient(
            store: TestCloudStore(),
            notificationCenter: NotificationCenter()
        )
        #expect(PreferencesStore(iCloudClient: client).syncMethod == .iCloud)
    }

    @Test("retains an unavailable saved iCloud choice for a future entitled build")
    func savedICloudFallback() throws {
        let suiteName = "katabro-sync-fallback-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("iCloud", forKey: "preferences.syncMethod.v1")
        let store = PreferencesStore.live(userDefaults: defaults, iCloudClient: nil)
        #expect(store.syncMethod == .thisMac)
        #expect(store.iCloudSelectionUnavailable)
        #expect(defaults.string(forKey: "preferences.syncMethod.v1") == "iCloud")
    }

    @Test("restores the selected folder name from its saved bookmark")
    func restoresFolderDisplayName() throws {
        let suiteName = "katabro-folder-restore-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let container = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: container) }
        let directory = container.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let bookmark = Data("bookmark".utf8)
        defaults.set(PreferencesStore.SyncMethod.folder.rawValue, forKey: "preferences.syncMethod.v1")
        defaults.set(bookmark, forKey: "preferences.folderBookmark.v1")
        let client = FilePreferencesClient(
            bookmarkData: bookmark,
            bookmarkResolver: { _ in (directory, false) },
            bookmarkMaker: { _ in throw CocoaError(.fileReadNoPermission) },
            injectedRead: {
                .snapshot(
                    BrowserSettingsSnapshot(browserOrder: [], pickerShortcuts: [:], exactHostRoutingRules: []),
                    bytes: Data("snapshot".utf8)
                )
            },
            startAccessing: { _ in true },
            stopAccessing: { _ in }
        )

        let store = PreferencesStore.live(
            userDefaults: defaults,
            iCloudClient: nil
        ) { _ in client }

        #expect(store.syncMethod == .folder)
        #expect(store.activeFolderDisplayName == "Documents")
        #expect(store.activeFolderLocation == client.displayLocation)
        #expect(store.folderSyncStatus == .active(displayName: "Documents"))
    }

    @Test("reports lost authorization when a saved Folder has no bookmark")
    func missingSavedFolderBookmark() throws {
        let suiteName = "katabro-folder-missing-bookmark-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(PreferencesStore.SyncMethod.folder.rawValue, forKey: "preferences.syncMethod.v1")

        let store = PreferencesStore.live(userDefaults: defaults, iCloudClient: nil)

        #expect(store.syncMethod == .folder)
        #expect(store.folderSyncStatus == .lostAuthorization)
    }

    @Test("failed folder activation retains the prior mode")
    func failedActivationRetainsMode() {
        let store = PreferencesStore()
        let missing = FilePreferencesClient(
            directoryURL: URL(fileURLWithPath: "/private/tmp/katabro-folder-does-not-exist")
        )
        #expect(!store.configureFolderSync(client: missing, displayName: "Missing"))
        #expect(store.syncMethod == .thisMac)
    }

    @Test("failed bookmark validation does not commit Folder metadata")
    func failedBookmarkRetainsMetadata() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let failingBookmarkMaker: @MainActor (URL) throws -> Data = { _ in
            throw CocoaError(.fileWriteUnknown)
        }
        let client = FilePreferencesClient(
            directoryURL: directory,
            bookmarkMaker: failingBookmarkMaker
        )
        let store = PreferencesStore(initialPreferences: AppPreferences(browserOrder: ["local"]))
        #expect(!store.configureFolderSync(client: client, displayName: "Rejected"))
        #expect(store.syncMethod == .thisMac)
        #expect(store.activeFolderDisplayName.isEmpty)
        #expect(store.activeFolderLocation.isEmpty)
        #expect(store.folderSyncStatus == .inactive)
    }

    @Test("adopting a snapshot replaces only the three shared fields")
    func adoptingSnapshot() throws {
        let shortcut = try #require(PickerShortcut("S"))
        let rule = try #require(
            ExactHostRoutingRule(host: "example.com", targetIdentifier: "opaque.profile")
        )
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: ["local"],
                hiddenBrowserIdentifiers: ["hidden"],
                hasCompletedOnboarding: true
            )
        )
        store.applyBrowserSettingsSnapshot(
            BrowserSettingsSnapshot(
                browserOrder: ["remote"],
                pickerShortcuts: ["remote": shortcut],
                exactHostRoutingRules: [rule]
            )
        )
        #expect(store.browserOrder == ["remote"])
        #expect(store.pickerShortcuts == ["remote": shortcut])
        #expect(store.exactHostRoutingRules == [rule])
        #expect(store.hiddenBrowserIdentifiers == ["hidden"])
        #expect(store.hasCompletedOnboarding)
    }

    @Test("folder writes preserve fields changed by another writer")
    func preservesRemoteFields() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("katabro-store-sync-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let remoteShortcut = try #require(PickerShortcut("R"))
        let client = FilePreferencesClient(directoryURL: directory)
        #expect(client.write(BrowserSettingsSnapshot(
            browserOrder: ["remote"],
            pickerShortcuts: ["remote": remoteShortcut],
            exactHostRoutingRules: []
        )))
        let store = PreferencesStore(initialPreferences: AppPreferences(browserOrder: ["local"]))
        #expect(store.configureFolderSync(client: client, displayName: "Provider"))
        #expect(store.syncMethod == .folder)
        store.setBrowserOrder(["changed"])
        #expect(store.browserOrder == ["changed"])
        #expect(store.folderSyncStatus == .active(displayName: "Provider"))
        let snapshot = try #require(client.read().snapshotValue)
        #expect(snapshot.browserOrder == ["changed"])
        #expect(snapshot.pickerShortcuts == ["remote": remoteShortcut])
    }

    @Test("folder rules never write iCloud keys")
    func rulesNeverWriteCloud() throws {
        let cloudStore = TestCloudStore()
        let cloudClient = ICloudPreferencesClient(
            store: cloudStore,
            notificationCenter: NotificationCenter()
        )
        let store = PreferencesStore(
            initialPreferences: AppPreferences(browserOrder: ["local"]),
            initialSyncStatus: .available,
            iCloudClient: cloudClient
        )
        // Rules are local-only while iCloud is active, preserving the existing contract.
        let destination = try IncomingURL("https://example.com")
        _ = store.setExactHostRoutingRule(for: destination, targetIdentifier: "opaque")
        #expect(cloudStore.writes.isEmpty)
    }

    @Test("each local Folder field write preserves the other fields")
    func preservesEveryRemoteField() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let remoteShortcut = try #require(PickerShortcut("R"))
        let remoteRule = try #require(
            ExactHostRoutingRule(host: "remote.example", targetIdentifier: "opaque.remote")
        )
        let client = FilePreferencesClient(directoryURL: directory)
        let remote = BrowserSettingsSnapshot(
            browserOrder: ["remote"],
            pickerShortcuts: ["remote": remoteShortcut],
            exactHostRoutingRules: [remoteRule]
        )
        #expect(client.write(remote))
        let store = PreferencesStore(
            initialPreferences: AppPreferences(browserOrder: ["local"]),
            syncMethod: .folder
        )
        #expect(store.configureFolderSync(client: client, displayName: "Provider"))

        store.setBrowserOrder(["local-order"])
        let afterOrder = try #require(client.read().snapshotValue)
        #expect(afterOrder.pickerShortcuts == ["remote": remoteShortcut])
        #expect(afterOrder.exactHostRoutingRules == [remoteRule])
        let localShortcut = try #require(PickerShortcut("L"))
        store.setPickerShortcut(localShortcut, for: "local")
        let afterShortcut = try #require(client.read().snapshotValue)
        #expect(afterShortcut.browserOrder == ["local-order"])
        #expect(afterShortcut.pickerShortcuts == ["local": localShortcut])
        #expect(afterShortcut.exactHostRoutingRules == [remoteRule])
        let localRule = try #require(ExactHostRoutingRule(host: "local.example", targetIdentifier: "opaque.local"))
        _ = try store.setExactHostRoutingRule(
            for: IncomingURL("https://local.example"),
            targetIdentifier: localRule.targetIdentifier
        )

        let snapshot = try #require(client.read().snapshotValue)
        #expect(snapshot.browserOrder == ["local-order"])
        #expect(snapshot.pickerShortcuts == ["local": localShortcut])
        #expect(!snapshot.exactHostRoutingRules.contains(remoteRule))
        #expect(snapshot.exactHostRoutingRules.contains(localRule))
    }

    @Test("bookmark data is persisted when Folder activation succeeds")
    func persistsBookmark() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var savedBookmark: Data?
        let client = FilePreferencesClient(
            directoryURL: directory,
            bookmarkMaker: { _ in Data("bookmark".utf8) },
            injectedRead: {
                .snapshot(
                    BrowserSettingsSnapshot(browserOrder: [], pickerShortcuts: [:], exactHostRoutingRules: []),
                    bytes: Data("{}".utf8)
                )
            }
        )
        // swiftlint:disable trailing_closure
        let store = PreferencesStore(
            syncMethod: .thisMac,
            saveFolderBookmark: { savedBookmark = $0 }
        )
        // swiftlint:enable trailing_closure
        #expect(store.configureFolderSync(client: client, displayName: "Provider"))
        #expect(savedBookmark == Data("bookmark".utf8))
    }

    @Test("invalid local writes remain local and recover after a valid file returns")
    func invalidWriteRecovery() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = FilePreferencesClient(directoryURL: directory)
        #expect(client.write(BrowserSettingsSnapshot(
            browserOrder: ["remote"],
            pickerShortcuts: [:],
            exactHostRoutingRules: []
        )))
        let store = PreferencesStore(initialPreferences: AppPreferences(browserOrder: ["local"]), syncMethod: .folder)
        #expect(store.configureFolderSync(client: client, displayName: "Provider"))
        try Data("invalid".utf8).write(to: directory.appendingPathComponent(FilePreferencesClient.fileName))
        store.setBrowserOrder(["kept-local"])
        #expect(store.browserOrder == ["kept-local"])
        #expect(store.folderSyncStatus == .invalid)
        let recovered = BrowserSettingsSnapshot(
            browserOrder: ["recovered"],
            pickerShortcuts: [:],
            exactHostRoutingRules: []
        )
        try recovered.encodedData().write(
            to: directory.appendingPathComponent(FilePreferencesClient.fileName)
        )
        store.refreshActiveSync()
        #expect(store.folderSyncStatus == .active(displayName: "Provider"))
    }

    @Test("Folder deletion is visible and recovery reactivates the transport")
    func deletionAndRecovery() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent(FilePreferencesClient.fileName)
        let snapshot = BrowserSettingsSnapshot(browserOrder: ["one"], pickerShortcuts: [:], exactHostRoutingRules: [])
        try snapshot.encodedData().write(to: file)
        let client = FilePreferencesClient(directoryURL: directory)
        let store = PreferencesStore(initialPreferences: AppPreferences(browserOrder: ["local"]))
        #expect(store.configureFolderSync(client: client, displayName: "Provider"))
        try FileManager.default.removeItem(at: file)
        store.refreshActiveSync()
        try await Task.sleep(for: .milliseconds(120))
        #expect(store.folderSyncStatus == .missingFile)
        try snapshot.encodedData().write(to: file)
        store.refreshActiveSync()
        try await Task.sleep(for: .milliseconds(120))
        #expect(store.folderSyncStatus == .active(displayName: "Provider"))
        #expect(store.browserOrder == ["one"])
    }

    @Test("external Folder snapshots apply without an echo write")
    func externalSnapshotNoEcho() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent(FilePreferencesClient.fileName)
        let first = BrowserSettingsSnapshot(browserOrder: ["one"], pickerShortcuts: [:], exactHostRoutingRules: [])
        let second = BrowserSettingsSnapshot(browserOrder: ["two"], pickerShortcuts: [:], exactHostRoutingRules: [])
        try first.encodedData().write(to: file)
        var saves = 0
        let client = FilePreferencesClient(directoryURL: directory)
        let save: (AppPreferences) -> Void = { _ in
            saves += 1
        }
        let store = PreferencesStore(
            initialPreferences: AppPreferences(browserOrder: ["local"]),
            save: save
        )
        #expect(store.configureFolderSync(client: client, displayName: "Provider"))
        try second.encodedData().write(to: file)
        store.refreshActiveSync()
        #expect(store.browserOrder == ["two"])
        #expect(saves == 2)
    }

    @Test("Folder seed and identical writes preserve a valid canonical snapshot")
    func seedAndIdenticalWrites() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = FilePreferencesClient(directoryURL: directory)
        let snapshot = BrowserSettingsSnapshot(browserOrder: ["seed"], pickerShortcuts: [:], exactHostRoutingRules: [])
        #expect(client.read() == .missing)
        #expect(client.write(snapshot))
        let firstBytes = try #require(client.read().bytesValue)
        #expect(client.write(snapshot))
        let secondBytes = try #require(client.read().bytesValue)
        #expect(firstBytes == secondBytes)
    }

    @Test("stops the old Folder transport before starting the new one")
    func switchesTransportInOrder() throws {
        let oldDirectory = try makeDirectory()
        let newDirectory = try makeDirectory()
        defer {
            try? FileManager.default.removeItem(at: oldDirectory)
            try? FileManager.default.removeItem(at: newDirectory)
        }
        let lifecycle = OSAllocatedUnfairLock(uncheckedState: [String]())
        let snapshot = BrowserSettingsSnapshot(browserOrder: ["old"], pickerShortcuts: [:], exactHostRoutingRules: [])
        let oldClient = FilePreferencesClient(
            directoryURL: oldDirectory,
            bookmarkMaker: { _ in Data("old".utf8) },
            injectedRead: { .snapshot(snapshot, bytes: Data("old".utf8)) },
            startAccessing: { _ in lifecycle.withLockUnchecked { $0.append("old.start") }; return true },
            stopAccessing: { _ in lifecycle.withLockUnchecked { $0.append("old.stop") } }
        )
        let newClient = FilePreferencesClient(
            directoryURL: newDirectory,
            bookmarkMaker: { _ in Data("new".utf8) },
            injectedRead: { .snapshot(snapshot, bytes: Data("new".utf8)) },
            startAccessing: { _ in lifecycle.withLockUnchecked { $0.append("new.start") }; return true },
            stopAccessing: { _ in lifecycle.withLockUnchecked { $0.append("new.stop") } }
        )
        let store = PreferencesStore()
        #expect(store.configureFolderSync(client: oldClient, displayName: "Old"))
        lifecycle.withLockUnchecked { $0.removeAll() }
        #expect(store.configureFolderSync(client: newClient, displayName: "New"))
        #expect(lifecycle.withLockUnchecked { $0 } == ["old.stop", "new.start"])
        #expect(store.folderSyncStatus == .active(displayName: "New"))
    }

    @Test("failed replacement rolls back to the prior Folder transport")
    func failedReplacementRollsBack() {
        let snapshot = BrowserSettingsSnapshot(browserOrder: ["old"], pickerShortcuts: [:], exactHostRoutingRules: [])
        var oldReads = 0
        let oldClient = FilePreferencesClient(
            injectedRead: {
                oldReads += 1
                return .snapshot(snapshot, bytes: Data("old".utf8))
            },
            displayName: "Old"
        )
        let failedClient = FilePreferencesClient(
            injectedRead: { .unavailable },
            displayName: "New"
        )
        let store = PreferencesStore()
        #expect(store.configureFolderSync(client: oldClient, displayName: "Old"))
        #expect(!store.configureFolderSync(client: failedClient, displayName: "New"))
        #expect(store.syncMethod == .folder)
        #expect(store.activeFolderDisplayName == "Old")
        #expect(store.activeFolderLocation == "Old")
        #expect(store.folderSyncStatus == .active(displayName: "Old"))
        #expect(oldReads >= 2)
    }

    @Test("malformed rules are rejected without changing local preferences")
    func malformedRulesAreAllOrNothing() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let malformed = Data(
            """
            {"version":1,"order":["remote"],"shortcuts":{},
            "routingRules":[{"matchHost":"","targetIdentifier":"opaque"}]}
            """.utf8
        )
        try malformed.write(to: directory.appendingPathComponent(FilePreferencesClient.fileName))
        let store = PreferencesStore(initialPreferences: AppPreferences(browserOrder: ["local"]))
        let client = FilePreferencesClient(directoryURL: directory)
        #expect(store.configureFolderSync(client: client, displayName: "Provider"))
        #expect(store.browserOrder == ["local"])
        #expect(store.folderSyncStatus == .invalid)
    }

    @Test("remote rule arrays win as an opaque last-writer-wins value")
    func remoteRulesWinAsWholeArray() throws {
        let firstRule = try #require(ExactHostRoutingRule(host: "one.example", targetIdentifier: "opaque.one"))
        let secondRule = try #require(ExactHostRoutingRule(host: "two.example", targetIdentifier: "opaque.two"))
        let remote = BrowserSettingsSnapshot(
            browserOrder: ["remote"],
            pickerShortcuts: [:],
            exactHostRoutingRules: [firstRule, secondRule]
        )
        let client = FilePreferencesClient(
            injectedRead: { .snapshot(remote, bytes: Data("remote".utf8)) },
            displayName: "Provider"
        )
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: ["local"],
                exactHostRoutingRules: [firstRule]
            )
        )
        #expect(store.configureFolderSync(client: client, displayName: "Provider"))
        #expect(store.exactHostRoutingRules == [firstRule, secondRule])
    }

    @Test("opaque unavailable targets remain in the shared rules")
    func opaqueUnavailableTargetIsPreserved() throws {
        let rule = try #require(
            ExactHostRoutingRule(host: "missing.example", targetIdentifier: "device.profile.opaque")
        )
        let snapshot = BrowserSettingsSnapshot(browserOrder: [], pickerShortcuts: [:], exactHostRoutingRules: [rule])
        let store = PreferencesStore()
        store.applyBrowserSettingsSnapshot(snapshot)
        #expect(store.exactHostRoutingRules == [rule])
    }

    @Test("local-only fields never enter the shared snapshot")
    func localOnlyFieldsAreExcluded() throws {
        let store = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: ["browser"],
                hiddenBrowserIdentifiers: ["hidden"],
                hasCompletedOnboarding: true
            )
        )
        let json = try String(data: store.browserSettingsSnapshot().encodedData(), encoding: .utf8)
        #expect(json?.contains("hiddenBrowserIdentifiers") == false)
        #expect(json?.contains("hasCompletedOnboarding") == false)
    }

    @Test("Folder and iCloud switches do not bridge rule or file writes")
    func folderAndCloudDoNotBridge() throws {
        let cloudStore = TestCloudStore()
        let cloudClient = ICloudPreferencesClient(store: cloudStore, notificationCenter: NotificationCenter())
        let folderSnapshot = BrowserSettingsSnapshot(
            browserOrder: ["folder"],
            pickerShortcuts: [:],
            exactHostRoutingRules: []
        )
        var folderWrites = 0
        let folderClient = FilePreferencesClient(
            injectedRead: { .snapshot(folderSnapshot, bytes: Data("folder".utf8)) },
            injectedWrite: { _ in
                folderWrites += 1
                return true
            },
            displayName: "Provider"
        )
        let store = PreferencesStore(iCloudClient: cloudClient, syncMethod: .thisMac)
        #expect(store.configureFolderSync(client: folderClient, displayName: "Provider"))
        #expect(store.setSyncMethod(.iCloud))
        folderWrites = 0
        cloudStore.writes.removeAll()
        store.setBrowserOrder(["cloud"])
        #expect(folderWrites == 0)
        #expect(cloudStore.writes.contains { $0.key == ICloudPreferencesClient.browserOrderKey })
        cloudStore.writes.removeAll()
        _ = try store.setExactHostRoutingRule(
            for: IncomingURL("https://folder.example"),
            targetIdentifier: "opaque"
        )
        #expect(cloudStore.writes.isEmpty)
        #expect(store.configureFolderSync(client: folderClient, displayName: "Provider"))
        folderWrites = 0
        cloudStore.writes.removeAll()
        store.setBrowserOrder(["local"])
        #expect(folderWrites == 1)
        #expect(cloudStore.writes.isEmpty)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("katabro-store-sync-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private extension FilePreferencesClient.ReadResult {
    var snapshotValue: BrowserSettingsSnapshot? {
        guard case let .snapshot(snapshot, _) = self else { return nil }
        return snapshot
    }

    var bytesValue: Data? {
        guard case let .snapshot(_, bytes) = self else { return nil }
        return bytes
    }
}

@MainActor
private final class TestCloudStore: ICloudKeyValueStoring {
    var values: [String: Any] = [:]
    var writes: [(key: String, value: Any?)] = []

    func object(forKey aKey: String) -> Any? {
        values[aKey]
    }

    func set(_ anObject: Any?, forKey aKey: String) {
        writes.append((aKey, anObject))
        values[aKey] = anObject
    }

    func synchronize() -> Bool {
        true
    }
}
