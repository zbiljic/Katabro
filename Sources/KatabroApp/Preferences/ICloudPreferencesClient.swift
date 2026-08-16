import Foundation

@MainActor
protocol ICloudKeyValueStoring: AnyObject {
    func object(forKey aKey: String) -> Any?
    func set(_ anObject: Any?, forKey aKey: String)
    func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: ICloudKeyValueStoring {}

@MainActor
final class ICloudPreferencesClient: NSObject {
    enum ReadResult: Equatable, Sendable {
        case missing
        case value([String])
        case invalid
    }

    enum PickerShortcutsReadResult: Equatable, Sendable {
        case missing
        case value([String: PickerShortcut])
        case invalid
    }

    enum ChangeReason: Equatable, Sendable {
        case serverChange
        case initialSync
        case accountChange
    }

    enum Event: Equatable, Sendable {
        case changed(
            reason: ChangeReason,
            keys: Set<String>?
        )
        case quotaViolation
    }

    static let browserOrderKey = "settings.browserOrder.v1"
    static let pickerShortcutsKey = "settings.pickerShortcuts.v1"

    private let store: any ICloudKeyValueStoring
    private let notificationCenter: NotificationCenter
    private var eventHandler: (@MainActor (Event) -> Void)?
    private var startResult: Bool?

    init(
        store: any ICloudKeyValueStoring,
        notificationCenter: NotificationCenter
    ) {
        self.store = store
        self.notificationCenter = notificationCenter
        super.init()
    }

    static func live(
        store: NSUbiquitousKeyValueStore = .default,
        notificationCenter: NotificationCenter = .default
    ) -> ICloudPreferencesClient {
        Self(
            store: store,
            notificationCenter: notificationCenter
        )
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    func readBrowserOrder() -> ReadResult {
        guard
            let value = store.object(
                forKey: Self.browserOrderKey
            )
        else {
            return .missing
        }

        guard let browserOrder = value as? [String] else {
            return .invalid
        }

        return .value(browserOrder)
    }

    func writeBrowserOrder(
        _ browserOrder: [String]
    ) {
        store.set(
            browserOrder,
            forKey: Self.browserOrderKey
        )
    }

    func readPickerShortcuts() -> PickerShortcutsReadResult {
        guard
            let value = store.object(
                forKey: Self.pickerShortcutsKey
            )
        else {
            return .missing
        }

        guard let encodedShortcuts = value as? [String: String] else {
            return .invalid
        }

        var shortcuts: [String: PickerShortcut] = [:]

        for (identifier, value) in encodedShortcuts {
            guard let shortcut = PickerShortcut(value) else {
                return .invalid
            }

            shortcuts[identifier] = shortcut
        }

        return .value(shortcuts)
    }

    func writePickerShortcuts(
        _ pickerShortcuts: [String: PickerShortcut]
    ) {
        store.set(
            pickerShortcuts.mapValues(\.rawValue),
            forKey: Self.pickerShortcutsKey
        )
    }

    func start(
        onEvent: @escaping @MainActor (Event) -> Void
    ) -> Bool {
        if let startResult {
            return startResult
        }

        eventHandler = onEvent
        notificationCenter.addObserver(
            self,
            selector: #selector(receiveExternalChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        let result = store.synchronize()
        startResult = result
        return result
    }

    /// Stop observation without discarding the client. This makes transport
    /// switching deterministic and permits a later restart.
    func stop() {
        notificationCenter.removeObserver(
            self,
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        eventHandler = nil
        startResult = nil
    }

    // swiftformat:disable modifierOrder
    @objc
    nonisolated private func receiveExternalChange(
        _ notification: Notification
    ) {
        guard let event = Self.event(from: notification) else {
            return
        }

        Task { @MainActor [weak self] in
            self?.eventHandler?(event)
        }
    }

    // swiftformat:enable modifierOrder

    // swiftformat:disable modifierOrder
    nonisolated private static func event(
        from notification: Notification
    ) -> Event? {
        guard
            let rawReason = notification.userInfo?[
                NSUbiquitousKeyValueStoreChangeReasonKey
            ] as? Int
        else {
            return nil
        }

        if rawReason == NSUbiquitousKeyValueStoreQuotaViolationChange {
            return .quotaViolation
        }

        let reason: ChangeReason

        switch rawReason {
        case NSUbiquitousKeyValueStoreServerChange:
            reason = .serverChange
        case NSUbiquitousKeyValueStoreInitialSyncChange:
            reason = .initialSync
        case NSUbiquitousKeyValueStoreAccountChange:
            reason = .accountChange
        default:
            return nil
        }

        let keys = (notification.userInfo?[
            NSUbiquitousKeyValueStoreChangedKeysKey
        ] as? [String]).map(Set.init)
        return .changed(
            reason: reason,
            keys: keys
        )
    }

    // swiftformat:enable modifierOrder
}
