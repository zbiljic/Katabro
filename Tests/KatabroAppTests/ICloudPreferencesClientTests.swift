import Foundation
@testable import Katabro
import Testing

@MainActor
@Suite("iCloud preferences client")
struct ICloudPreferencesClientTests {
    @Test("reads valid, empty, missing, and invalid browser orders")
    func readsBrowserOrders() {
        let store = InMemoryKeyValueStore()
        let client = makeClient(store: store)

        #expect(client.readBrowserOrder() == .missing)

        store.values[ICloudPreferencesClient.browserOrderKey] = ["one", "two"]
        #expect(client.readBrowserOrder() == .value(["one", "two"]))

        store.values[ICloudPreferencesClient.browserOrderKey] = [String]()
        #expect(client.readBrowserOrder() == .value([]))

        store.values[ICloudPreferencesClient.browserOrderKey] = "not an array"
        #expect(client.readBrowserOrder() == .invalid)
    }

    @Test("writes only the exact browser order key")
    func writesBrowserOrder() {
        let store = InMemoryKeyValueStore()
        let client = makeClient(store: store)

        client.writeBrowserOrder(["one", "two"])

        #expect(store.writes.count == 1)
        #expect(store.writes.first?.key == "settings.browserOrder.v1")
        #expect(store.writes.first?.value as? [String] == ["one", "two"])
        #expect(store.synchronizeCallCount == 0)
    }

    @Test("reads valid, empty, missing, and invalid picker shortcuts")
    func readsPickerShortcuts() throws {
        let store = InMemoryKeyValueStore()
        let client = makeClient(store: store)

        #expect(client.readPickerShortcuts() == .missing)

        store.values[ICloudPreferencesClient.pickerShortcutsKey] = [
            "browser.one": "a",
            "browser.two": "Z",
        ]
        #expect(
            try client.readPickerShortcuts() == .value([
                "browser.one": #require(PickerShortcut("A")),
                "browser.two": #require(PickerShortcut("Z")),
            ])
        )

        store.values[ICloudPreferencesClient.pickerShortcutsKey] = [String: String]()
        #expect(client.readPickerShortcuts() == .value([:]))

        store.values[ICloudPreferencesClient.pickerShortcutsKey] = ["browser": "1"]
        #expect(client.readPickerShortcuts() == .invalid)

        store.values[ICloudPreferencesClient.pickerShortcutsKey] = ["not", "a", "dictionary"]
        #expect(client.readPickerShortcuts() == .invalid)
    }

    @Test("writes picker shortcuts under their versioned key")
    func writesPickerShortcuts() throws {
        let store = InMemoryKeyValueStore()
        let client = makeClient(store: store)

        try client.writePickerShortcuts([
            "browser.one": #require(PickerShortcut("a")),
        ])

        #expect(store.writes.count == 1)
        #expect(store.writes.first?.key == "settings.pickerShortcuts.v1")
        #expect(store.writes.first?.value as? [String: String] == ["browser.one": "A"])
        #expect(store.synchronizeCallCount == 0)
    }

    @Test("registers before synchronizing and starts only once")
    func startsIdempotently() async {
        let notificationCenter = NotificationCenter()
        let store = InMemoryKeyValueStore()
        var events: [ICloudPreferencesClient.Event] = []
        store.onSynchronize = {
            notificationCenter.post(
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: store,
                userInfo: [
                    NSUbiquitousKeyValueStoreChangeReasonKey:
                        NSUbiquitousKeyValueStoreInitialSyncChange,
                ]
            )
            return true
        }
        let client = ICloudPreferencesClient(
            store: store,
            notificationCenter: notificationCenter
        )

        #expect(client.start { events.append($0) })
        #expect(client.start { _ in Issue.record("start replaced its callback") })
        await Task.yield()

        #expect(store.synchronizeCallCount == 1)
        #expect(
            events == [
                .changed(
                    reason: .initialSync,
                    keys: nil
                ),
            ]
        )
    }

    @Test("returns a failed synchronization result")
    func reportsSynchronizationFailure() {
        let store = InMemoryKeyValueStore()
        store.onSynchronize = { false }
        let client = makeClient(store: store)

        #expect(!client.start { _ in })
        #expect(!client.start { _ in })
        #expect(store.synchronizeCallCount == 1)
    }

    @Test("preserves notification reasons and changed keys")
    func emitsChangeReasonsAndKeys() async {
        let notificationCenter = NotificationCenter()
        let store = InMemoryKeyValueStore()
        let client = ICloudPreferencesClient(
            store: store,
            notificationCenter: notificationCenter
        )
        var events: [ICloudPreferencesClient.Event] = []
        _ = client.start { events.append($0) }

        post(
            reason: NSUbiquitousKeyValueStoreServerChange,
            keys: [
                ICloudPreferencesClient.browserOrderKey,
                ICloudPreferencesClient.pickerShortcutsKey,
                "unrelated",
            ],
            store: store,
            notificationCenter: notificationCenter
        )
        post(
            reason: NSUbiquitousKeyValueStoreInitialSyncChange,
            store: store,
            notificationCenter: notificationCenter
        )
        post(
            reason: NSUbiquitousKeyValueStoreAccountChange,
            store: store,
            notificationCenter: notificationCenter
        )
        post(
            reason: NSUbiquitousKeyValueStoreQuotaViolationChange,
            keys: ["unrelated"],
            store: store,
            notificationCenter: notificationCenter
        )
        await Task.yield()

        #expect(
            events == [
                .changed(
                    reason: .serverChange,
                    keys: [
                        ICloudPreferencesClient.browserOrderKey,
                        ICloudPreferencesClient.pickerShortcutsKey,
                        "unrelated",
                    ]
                ),
                .changed(
                    reason: .initialSync,
                    keys: nil
                ),
                .changed(
                    reason: .accountChange,
                    keys: nil
                ),
                .quotaViolation,
            ]
        )
    }

    @Test("removes its notification observer on deinitialization")
    func removesObserver() async {
        let notificationCenter = NotificationCenter()
        let store = InMemoryKeyValueStore()
        var events: [ICloudPreferencesClient.Event] = []
        var client: ICloudPreferencesClient? = ICloudPreferencesClient(
            store: store,
            notificationCenter: notificationCenter
        )
        _ = client?.start { events.append($0) }

        client = nil
        post(
            reason: NSUbiquitousKeyValueStoreServerChange,
            keys: [ICloudPreferencesClient.browserOrderKey],
            store: store,
            notificationCenter: notificationCenter
        )
        await Task.yield()

        #expect(events.isEmpty)
    }

    private func makeClient(
        store: InMemoryKeyValueStore
    ) -> ICloudPreferencesClient {
        ICloudPreferencesClient(
            store: store,
            notificationCenter: NotificationCenter()
        )
    }

    private func post(
        reason: Int,
        keys: [String]? = nil,
        store: InMemoryKeyValueStore,
        notificationCenter: NotificationCenter
    ) {
        var userInfo: [AnyHashable: Any] = [
            NSUbiquitousKeyValueStoreChangeReasonKey: reason,
        ]

        if let keys {
            userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] = keys
        }

        notificationCenter.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            userInfo: userInfo
        )
    }
}

@MainActor
private final class InMemoryKeyValueStore: ICloudKeyValueStoring {
    struct Write {
        let key: String
        let value: Any?
    }

    var values: [String: Any] = [:]
    var writes: [Write] = []
    var synchronizeCallCount = 0
    var onSynchronize: () -> Bool = { true }

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
        return onSynchronize()
    }
}
