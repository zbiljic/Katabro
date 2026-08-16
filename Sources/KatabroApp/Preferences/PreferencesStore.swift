import Foundation
import KatabroCore
import Observation

// Visibility and iCloud reconciliation intentionally share the aggregate preference owner.
// swiftlint:disable file_length type_body_length
@MainActor
@Observable
final class PreferencesStore {
    enum SyncMethod: String, Codable, Equatable, Sendable, CaseIterable {
        case thisMac
        case iCloud
        case folder

        var displayName: String {
            switch self {
            case .thisMac: "This Mac"
            case .iCloud: "iCloud"
            case .folder: "Folder"
            }
        }
    }

    enum FolderSyncStatus: Equatable, Sendable {
        case inactive
        case active(displayName: String)
        case missingFile
        case invalid
        case unavailable
        case lostAuthorization
    }

    enum ICloudSyncStatus: Equatable, Sendable {
        case available
        case localOnly
        case invalidCloudValue
    }

    private enum Key {
        static let preferences = "app.preferences"
        static let syncMethod = "preferences.syncMethod.v1"
        static let folderBookmark = "preferences.folderBookmark.v1"
    }

    private enum UpdateOrigin: Equatable {
        case browserOrder
        case pickerShortcuts
        case folderBrowserOrder
        case folderPickerShortcuts
        case folderRules
        case remote
        case local
    }

    private struct TransportState {
        let method: SyncMethod
        let client: FilePreferencesClient?
        let displayName: String
        let location: String
        let folderStatus: FolderSyncStatus
        let cloudWasActive: Bool
    }

    @ObservationIgnored private let save: (AppPreferences) -> Void
    @ObservationIgnored private let iCloudClient: ICloudPreferencesClient?
    @ObservationIgnored private var fileClient: FilePreferencesClient?
    private(set) var activeFolderDisplayName = ""
    private(set) var activeFolderLocation = ""
    @ObservationIgnored private let saveSyncMethod: (SyncMethod) -> Void
    @ObservationIgnored private let saveFolderBookmark: (Data?) -> Void

    private(set) var preferences: AppPreferences
    private(set) var iCloudSyncStatus: ICloudSyncStatus
    private(set) var syncMethod: SyncMethod
    private(set) var folderSyncStatus: FolderSyncStatus
    private(set) var iCloudSelectionUnavailable = false

    var iCloudSyncAvailable: Bool {
        iCloudClient != nil
    }

    var browserOrder: [String] {
        preferences.browserOrder
    }

    var hiddenBrowserIdentifiers: [String] {
        preferences.hiddenBrowserIdentifiers
    }

    var pickerShortcuts: [String: PickerShortcut] {
        preferences.pickerShortcuts
    }

    var hasCompletedOnboarding: Bool {
        preferences.hasCompletedOnboarding
    }

    var exactHostRoutingRules: [ExactHostRoutingRule] {
        preferences.exactHostRoutingRules
    }

    private init(
        initialPreferences: AppPreferences = AppPreferences(),
        initialSyncStatus: ICloudSyncStatus = .localOnly,
        iCloudClient: ICloudPreferencesClient? = nil,
        resolvedSyncMethod: SyncMethod,
        saveSyncMethod: @escaping (SyncMethod) -> Void = { _ in },
        saveFolderBookmark: @escaping (Data?) -> Void = { _ in },
        save: @escaping (AppPreferences) -> Void = { _ in }
    ) {
        var normalizedPreferences = initialPreferences
        normalizedPreferences.hiddenBrowserIdentifiers = Self.normalizedIdentifiers(
            initialPreferences.hiddenBrowserIdentifiers
        )
        normalizedPreferences.pickerShortcuts = Self.normalizedPickerShortcuts(
            initialPreferences.pickerShortcuts
        )
        normalizedPreferences.exactHostRoutingRules = Self.normalizedExactHostRoutingRules(
            initialPreferences.exactHostRoutingRules
        )
        preferences = normalizedPreferences
        iCloudSyncStatus = initialSyncStatus
        self.iCloudClient = iCloudClient
        syncMethod = resolvedSyncMethod
        folderSyncStatus = .inactive
        self.saveSyncMethod = saveSyncMethod
        self.saveFolderBookmark = saveFolderBookmark
        self.save = save
    }

    convenience init(
        initialPreferences: AppPreferences = AppPreferences(),
        initialSyncStatus: ICloudSyncStatus = .localOnly,
        iCloudClient: ICloudPreferencesClient? = nil,
        save: @escaping (AppPreferences) -> Void = { _ in }
    ) {
        self.init(
            initialPreferences: initialPreferences,
            initialSyncStatus: initialSyncStatus,
            iCloudClient: iCloudClient,
            resolvedSyncMethod: iCloudClient == nil ? .thisMac : .iCloud,
            saveSyncMethod: { _ in },
            saveFolderBookmark: { _ in },
            save: save
        )
    }

    convenience init(
        initialPreferences: AppPreferences = AppPreferences(),
        initialSyncStatus: ICloudSyncStatus = .localOnly,
        iCloudClient: ICloudPreferencesClient? = nil,
        syncMethod: SyncMethod,
        saveSyncMethod: @escaping (SyncMethod) -> Void = { _ in },
        saveFolderBookmark: @escaping (Data?) -> Void = { _ in },
        save: @escaping (AppPreferences) -> Void = { _ in }
    ) {
        self.init(
            initialPreferences: initialPreferences,
            initialSyncStatus: initialSyncStatus,
            iCloudClient: iCloudClient,
            resolvedSyncMethod: syncMethod,
            saveSyncMethod: saveSyncMethod,
            saveFolderBookmark: saveFolderBookmark,
            save: save
        )
    }

    static func live(
        userDefaults: UserDefaults = .standard
    ) -> PreferencesStore {
        #if KATABRO_ICLOUD
            live(
                userDefaults: userDefaults,
                iCloudClient: .live()
            )
        #else
            live(
                userDefaults: userDefaults,
                iCloudClient: nil
            )
        #endif
    }

    static func live(
        userDefaults: UserDefaults,
        iCloudClient: ICloudPreferencesClient?,
        defaultPreferences: AppPreferences = AppPreferences(),
        folderClient: (Data) -> FilePreferencesClient = { bookmark in
            FilePreferencesClient(bookmarkData: bookmark)
        }
    ) -> PreferencesStore {
        let data = userDefaults.data(
            forKey: Key.preferences
        )
        let preferences = data.flatMap { data in
            try? JSONDecoder().decode(
                AppPreferences.self,
                from: data
            )
        } ?? defaultPreferences

        let store = Self(
            initialPreferences: preferences,
            iCloudClient: iCloudClient,
            resolvedSyncMethod: {
                let saved = userDefaults.string(forKey: Key.syncMethod).flatMap(SyncMethod.init(rawValue:))
                if saved == .iCloud, iCloudClient == nil {
                    return .thisMac
                }
                return saved ?? (iCloudClient == nil ? .thisMac : .iCloud)
            }(),
            saveSyncMethod: { method in
                userDefaults.set(method.rawValue, forKey: Key.syncMethod)
            },
            saveFolderBookmark: { bookmark in
                userDefaults.set(bookmark, forKey: Key.folderBookmark)
            },
            save: { preferences in
                guard let data = try? JSONEncoder().encode(preferences) else {
                    return
                }

                userDefaults.set(
                    data,
                    forKey: Key.preferences
                )
            }
        )
        let savedICloudWithoutClient = userDefaults.string(forKey: Key.syncMethod) == SyncMethod.iCloud.rawValue
            && iCloudClient == nil
        if savedICloudWithoutClient {
            store.iCloudSelectionUnavailable = true
        }
        if store.syncMethod == .iCloud, iCloudClient != nil {
            store.startICloudSync()
        }
        if store.syncMethod == .folder {
            restoreFolderSync(store, userDefaults: userDefaults, folderClient: folderClient)
        }
        return store
    }

    private static func restoreFolderSync(
        _ store: PreferencesStore,
        userDefaults: UserDefaults,
        folderClient: (Data) -> FilePreferencesClient
    ) {
        guard let bookmark = userDefaults.data(forKey: Key.folderBookmark) else {
            store.folderSyncStatus = .lostAuthorization
            return
        }
        let client = folderClient(bookmark)
        guard let resolved = try? client.resolveBookmark() else {
            store.folderSyncStatus = .lostAuthorization
            return
        }
        let displayName = resolved.url.lastPathComponent
        store.activeFolderDisplayName = displayName
        store.activeFolderLocation = client.displayLocation
        if !store.configureFolderSync(client: client, displayName: displayName) {
            store.folderSyncStatus = .unavailable
        }
        if let refreshed = resolved.refreshedBookmark {
            userDefaults.set(refreshed, forKey: Key.folderBookmark)
        }
    }

    func browserSettingsSnapshot() -> BrowserSettingsSnapshot {
        BrowserSettingsSnapshot(
            browserOrder: Self.normalizedOrder(browserOrder),
            pickerShortcuts: Self.normalizedPickerShortcuts(pickerShortcuts),
            exactHostRoutingRules: Self.normalizedExactHostRoutingRules(exactHostRoutingRules)
        )
    }

    func applyBrowserSettingsSnapshot(_ snapshot: BrowserSettingsSnapshot) {
        var updated = preferences
        updated.browserOrder = Self.normalizedOrder(snapshot.browserOrder)
        updated.pickerShortcuts = Self.normalizedPickerShortcuts(snapshot.pickerShortcuts)
        updated.exactHostRoutingRules = Self.normalizedExactHostRoutingRules(snapshot.exactHostRoutingRules)
        update(updated, origin: .remote)
    }

    @discardableResult
    func configureFolderSync(
        client: FilePreferencesClient,
        displayName: String
    ) -> Bool {
        let previousTransport = transportState

        let bookmark: Data?
        do {
            bookmark = try client.bookmarkDataForDirectory()
        } catch {
            return false
        }

        stopICloudSync()
        previousTransport.client?.stop()
        fileClient = nil
        guard
            client.start(onEvent: { [weak self] event in
                self?.handleFolderEvent(event)
            }, refreshImmediately: false)
        else {
            client.stop()
            restoreTransport(previousTransport)
            return false
        }

        let initialRead = client.read()
        guard initialRead != .unavailable else {
            client.stop()
            restoreTransport(previousTransport)
            return false
        }

        fileClient = client
        activeFolderDisplayName = displayName
        activeFolderLocation = client.displayLocation
        syncMethod = .folder
        saveSyncMethod(.folder)
        saveFolderBookmark(bookmark)
        client.setEventHandler { [weak self] event in
            self?.handleFolderEvent(event)
        }
        client.refresh()
        switch initialRead {
        case .unavailable:
            folderSyncStatus = .unavailable
        case .invalid:
            folderSyncStatus = .invalid
        case .missing:
            folderSyncStatus = .missingFile
        case .snapshot:
            folderSyncStatus = .active(displayName: displayName)
        }
        return true
    }

    private var transportState: TransportState {
        TransportState(
            method: syncMethod,
            client: fileClient,
            displayName: activeFolderDisplayName,
            location: activeFolderLocation,
            folderStatus: folderSyncStatus,
            cloudWasActive: iCloudSyncStatus == .available
        )
    }

    private func restoreTransport(_ state: TransportState) {
        syncMethod = state.method
        activeFolderDisplayName = state.displayName
        activeFolderLocation = state.location
        folderSyncStatus = state.folderStatus
        fileClient = state.client
        if state.method == .folder, let client = state.client {
            _ = client.start { [weak self] event in
                self?.handleFolderEvent(event)
            }
        } else if state.method == .iCloud, state.cloudWasActive {
            _ = startICloudSync()
        }
    }

    func stopFolderSync() {
        fileClient?.stop()
        fileClient = nil
        folderSyncStatus = .inactive
    }

    @discardableResult
    func setSyncMethod(_ method: SyncMethod) -> Bool {
        guard method != syncMethod else { return true }
        switch method {
        case .thisMac:
            stopICloudSync()
            stopFolderSync()
            syncMethod = .thisMac
            saveSyncMethod(.thisMac)
            return true
        case .iCloud:
            guard iCloudClient != nil else { return false }
            let previousTransport = transportState
            stopICloudSync()
            previousTransport.client?.stop()
            fileClient = nil
            syncMethod = .iCloud
            guard startICloudSync() else {
                restoreTransport(previousTransport)
                return false
            }
            saveSyncMethod(.iCloud)
            return true
        case .folder:
            return false
        }
    }

    func refreshActiveSync() {
        if syncMethod == .folder {
            fileClient?.refresh()
        }
    }

    func orderedBrowsers(
        _ browsers: [BrowserApplication]
    ) -> [BrowserApplication] {
        var applicationsByIdentifier: [String: BrowserApplication] = [:]

        for browser in browsers {
            let identifier = browser.browser.bundleIdentifier.lowercased()

            if applicationsByIdentifier[identifier] == nil {
                applicationsByIdentifier[identifier] = browser
            }
        }

        var usedIdentifiers = Set<String>()
        var orderedBrowsers: [BrowserApplication] = []

        for identifier in browserOrder.map({ $0.lowercased() }) {
            guard
                let browser = applicationsByIdentifier[identifier],
                usedIdentifiers.insert(identifier).inserted
            else {
                continue
            }

            orderedBrowsers.append(browser)
        }

        for browser in browsers {
            let identifier = browser.browser.bundleIdentifier.lowercased()

            if usedIdentifiers.insert(identifier).inserted {
                orderedBrowsers.append(browser)
            }
        }

        return orderedBrowsers
    }

    func effectiveVisibleBrowsers(
        _ browsers: [BrowserApplication]
    ) -> [BrowserApplication] {
        let hiddenIdentifiers = Set(
            hiddenBrowserIdentifiers.map { $0.lowercased() }
        )
        let visibleBrowsers = browsers.filter { browser in
            !hiddenIdentifiers.contains(
                browser.browser.bundleIdentifier.lowercased()
            )
        }

        if visibleBrowsers.isEmpty, let firstBrowser = browsers.first {
            return [firstBrowser]
        }

        return visibleBrowsers
    }

    func isBrowserShown(
        _ bundleIdentifier: String,
        among discoveredBrowserIdentifiers: [String]
    ) -> Bool {
        let identifier = bundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return effectiveVisibleIdentifiers(
            discoveredBrowserIdentifiers
        ).contains { $0.lowercased() == identifier }
    }

    func canHideBrowser(
        _ bundleIdentifier: String,
        among discoveredBrowserIdentifiers: [String]
    ) -> Bool {
        let effectiveIdentifiers = effectiveVisibleIdentifiers(
            discoveredBrowserIdentifiers
        )
        let identifier = bundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return effectiveIdentifiers.count > 1
            && effectiveIdentifiers.contains {
                $0.lowercased() == identifier
            }
    }

    @discardableResult
    func setBrowserShown(
        _ bundleIdentifier: String,
        shown: Bool,
        among discoveredBrowserIdentifiers: [String]
    ) -> Bool {
        let discoveredIdentifiers = Self.normalizedIdentifiers(
            discoveredBrowserIdentifiers
        )
        let requestedIdentifier = bundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard
            let canonicalIdentifier = discoveredIdentifiers.first(where: {
                $0.lowercased() == requestedIdentifier
            })
        else {
            return false
        }

        let isHidden = hiddenBrowserIdentifiers.contains {
            $0.lowercased() == requestedIdentifier
        }

        if shown {
            guard isHidden else {
                return false
            }

            var preferences = preferences
            preferences.hiddenBrowserIdentifiers.removeAll {
                $0.lowercased() == requestedIdentifier
            }
            update(
                preferences,
                origin: .local
            )
            return true
        }

        guard
            !isHidden, canHideBrowser(
                canonicalIdentifier,
                among: discoveredIdentifiers
            )
        else {
            return false
        }

        var preferences = preferences
        preferences.hiddenBrowserIdentifiers = Self.normalizedIdentifiers(
            preferences.hiddenBrowserIdentifiers + [canonicalIdentifier]
        )
        update(
            preferences,
            origin: .local
        )
        return true
    }

    @discardableResult
    func showAllBrowsers() -> Bool {
        guard !hiddenBrowserIdentifiers.isEmpty else {
            return false
        }

        var preferences = preferences
        preferences.hiddenBrowserIdentifiers = []
        update(
            preferences,
            origin: .local
        )
        return true
    }

    func pickerShortcut(
        for bundleIdentifier: String
    ) -> PickerShortcut? {
        preferences.pickerShortcuts[
            Self.normalizedIdentifier(bundleIdentifier)
        ]
    }

    @discardableResult
    func setPickerShortcut(
        _ shortcut: PickerShortcut?,
        for bundleIdentifier: String
    ) -> Bool {
        let identifier = Self.normalizedIdentifier(bundleIdentifier)

        guard !identifier.isEmpty else {
            return false
        }

        var preferences = preferences

        if let shortcut {
            preferences.pickerShortcuts = preferences.pickerShortcuts.filter {
                $0.value != shortcut
            }
            preferences.pickerShortcuts[identifier] = shortcut
        } else {
            preferences.pickerShortcuts.removeValue(
                forKey: identifier
            )
        }

        let changed = self.preferences != preferences
        update(
            preferences,
            origin: syncMethod == .folder ? .folderPickerShortcuts : .pickerShortcuts
        )
        return changed
    }

    func setVisibleBrowserOrder(
        _ bundleIdentifiers: [String]
    ) {
        let normalizedVisibleOrder = Self.normalizedOrder(
            bundleIdentifiers
        )
        let normalizedStoredOrder = Self.normalizedOrder(
            browserOrder
        )
        let storedIdentifiers = Set(
            normalizedStoredOrder.map { $0.lowercased() }
        )
        let visibleIdentifiers = Set(
            normalizedVisibleOrder.map { $0.lowercased() }
        )
        var reorderedStoredIdentifiers = normalizedVisibleOrder
            .filter {
                storedIdentifiers.contains($0.lowercased())
            }
            .makeIterator()
        var mergedOrder = normalizedStoredOrder.map { identifier in
            guard visibleIdentifiers.contains(identifier.lowercased()) else {
                return identifier
            }

            return reorderedStoredIdentifiers.next() ?? identifier
        }

        mergedOrder.append(
            contentsOf: normalizedVisibleOrder.filter {
                !storedIdentifiers.contains($0.lowercased())
            }
        )
        setBrowserOrder(mergedOrder)
    }

    func setBrowserOrder(
        _ bundleIdentifiers: [String]
    ) {
        var preferences = preferences
        preferences.browserOrder = Self.normalizedOrder(
            bundleIdentifiers
        )
        update(
            preferences,
            origin: syncMethod == .folder ? .folderBrowserOrder : .browserOrder
        )
    }

    func moveBrowser(
        from source: IndexSet,
        to destination: Int
    ) {
        var order = browserOrder
        order.move(
            fromOffsets: source,
            toOffset: destination
        )
        setBrowserOrder(order)
    }

    func resetBrowserOrder() {
        setBrowserOrder([])
    }

    func completeOnboarding() {
        var preferences = preferences
        preferences.hasCompletedOnboarding = true
        update(
            preferences,
            origin: .local
        )
    }

    @discardableResult
    func setExactHostRoutingRule(
        for destination: IncomingURL,
        targetIdentifier: String
    ) -> Bool {
        guard
            let host = destination.url.host(),
            let rule = ExactHostRoutingRule(
                host: host,
                targetIdentifier: targetIdentifier
            )
        else {
            return false
        }

        var preferences = preferences

        let existingRuleIndex = preferences.exactHostRoutingRules.firstIndex {
            $0.host == rule.host
        }
        if let index = existingRuleIndex {
            preferences.exactHostRoutingRules[index] = rule
        } else {
            preferences.exactHostRoutingRules.append(rule)
        }

        let changed = self.preferences != preferences
        update(
            preferences,
            origin: syncMethod == .folder ? .folderRules : .local
        )
        return changed
    }

    @discardableResult
    func removeExactHostRoutingRule(
        host: String
    ) -> Bool {
        guard let normalizedHost = ExactHostRoutingRule.normalizedHost(host) else {
            return false
        }

        var preferences = preferences
        preferences.exactHostRoutingRules.removeAll {
            $0.host == normalizedHost
        }
        let changed = self.preferences != preferences
        update(
            preferences,
            origin: syncMethod == .folder ? .folderRules : .local
        )
        return changed
    }

    @discardableResult
    func removeAllExactHostRoutingRules() -> Bool {
        guard !preferences.exactHostRoutingRules.isEmpty else {
            return false
        }

        var preferences = preferences
        preferences.exactHostRoutingRules = []
        update(
            preferences,
            origin: syncMethod == .folder ? .folderRules : .local
        )
        return true
    }

    private func update(
        _ preferences: AppPreferences,
        origin: UpdateOrigin
    ) {
        guard self.preferences != preferences else {
            return
        }

        self.preferences = preferences
        save(preferences)

        switch origin {
        case .browserOrder:
            guard iCloudSyncStatus == .available else { return }
            iCloudClient?.writeBrowserOrder(preferences.browserOrder)
        case .pickerShortcuts:
            guard iCloudSyncStatus == .available else { return }
            iCloudClient?.writePickerShortcuts(preferences.pickerShortcuts)
        case .folderBrowserOrder:
            writeFolderField(.browserOrder)
        case .folderPickerShortcuts:
            writeFolderField(.pickerShortcuts)
        case .folderRules:
            writeFolderField(.exactHostRoutingRules)
        case .remote, .local:
            break
        }
    }

    @discardableResult
    func startICloudSync() -> Bool {
        guard syncMethod == .iCloud, let iCloudClient else {
            return false
        }

        let didStart = iCloudClient.start { [weak self] event in
            self?.handleICloudEvent(event)
        }

        guard didStart else {
            iCloudSyncStatus = .localOnly
            return false
        }

        applyCloudPreferences(
            seedWhenMissing: true
        )
        return true
    }

    func stopICloudSync() {
        iCloudClient?.stop()
        iCloudSyncStatus = .localOnly
    }

    private enum FolderField {
        case browserOrder
        case pickerShortcuts
        case exactHostRoutingRules
    }

    private func handleFolderEvent(_ event: FilePreferencesClient.Event) {
        switch event {
        case let .snapshot(snapshot):
            applyBrowserSettingsSnapshot(snapshot)
            folderSyncStatus = .active(displayName: activeFolderDisplayName)
        case .missing:
            folderSyncStatus = .missingFile
        case .invalid:
            folderSyncStatus = .invalid
        case .unavailable:
            folderSyncStatus = .unavailable
        }
    }

    private func writeFolderField(_ field: FolderField) {
        guard syncMethod == .folder, let fileClient else { return }
        let currentRead = fileClient.read()
        guard case let .snapshot(remote, _) = currentRead else {
            switch currentRead {
            case .missing: folderSyncStatus = .missingFile
            case .invalid: folderSyncStatus = .invalid
            case .unavailable: folderSyncStatus = .unavailable
            case .snapshot: break
            }
            return
        }
        let local = browserSettingsSnapshot()
        let merged = switch field {
        case .browserOrder:
            BrowserSettingsSnapshot(
                browserOrder: local.browserOrder,
                pickerShortcuts: remote.pickerShortcuts,
                exactHostRoutingRules: remote.exactHostRoutingRules
            )
        case .pickerShortcuts:
            BrowserSettingsSnapshot(
                browserOrder: remote.browserOrder,
                pickerShortcuts: local.pickerShortcuts,
                exactHostRoutingRules: remote.exactHostRoutingRules
            )
        case .exactHostRoutingRules:
            BrowserSettingsSnapshot(
                browserOrder: remote.browserOrder,
                pickerShortcuts: remote.pickerShortcuts,
                exactHostRoutingRules: local.exactHostRoutingRules
            )
        }
        folderSyncStatus = fileClient.write(merged)
            ? .active(displayName: activeFolderDisplayName)
            : .unavailable
    }

    private func handleICloudEvent(
        _ event: ICloudPreferencesClient.Event
    ) {
        switch event {
        case let .changed(reason, keys):
            let synchronizedKeys: Set<String> = [
                ICloudPreferencesClient.browserOrderKey,
                ICloudPreferencesClient.pickerShortcutsKey,
            ]
            let ignoresPreferences = reason == .serverChange
                && keys?.isDisjoint(with: synchronizedKeys) == true

            if ignoresPreferences {
                return
            }

            applyCloudPreferences(
                seedWhenMissing: false
            )
        case .quotaViolation:
            iCloudSyncStatus = .localOnly
        }
    }

    private func applyCloudPreferences(
        seedWhenMissing: Bool
    ) {
        let browserOrderIsValid = applyCloudBrowserOrder(
            seedWhenMissing: seedWhenMissing
        )
        let pickerShortcutsAreValid = applyCloudPickerShortcuts(
            seedWhenMissing: seedWhenMissing
        )

        iCloudSyncStatus = browserOrderIsValid && pickerShortcutsAreValid
            ? .available
            : .invalidCloudValue
    }

    private func applyCloudBrowserOrder(
        seedWhenMissing: Bool
    ) -> Bool {
        guard let iCloudClient else {
            return true
        }

        switch iCloudClient.readBrowserOrder() {
        case let .value(browserOrder):
            var preferences = preferences
            preferences.browserOrder = Self.normalizedOrder(browserOrder)
            update(
                preferences,
                origin: .remote
            )
            return true
        case .missing:
            let normalizedOrder = Self.normalizedOrder(browserOrder)
            var preferences = preferences
            preferences.browserOrder = normalizedOrder
            update(
                preferences,
                origin: .remote
            )
            if seedWhenMissing {
                iCloudClient.writeBrowserOrder(normalizedOrder)
            }
            return true
        case .invalid:
            return false
        }
    }

    private func applyCloudPickerShortcuts(
        seedWhenMissing: Bool
    ) -> Bool {
        guard let iCloudClient else {
            return true
        }

        switch iCloudClient.readPickerShortcuts() {
        case let .value(pickerShortcuts):
            var preferences = preferences
            preferences.pickerShortcuts = Self.normalizedPickerShortcuts(
                pickerShortcuts
            )
            update(
                preferences,
                origin: .remote
            )
            return true
        case .missing:
            let normalizedShortcuts = Self.normalizedPickerShortcuts(
                pickerShortcuts
            )
            var preferences = preferences
            preferences.pickerShortcuts = normalizedShortcuts
            update(
                preferences,
                origin: .remote
            )

            if seedWhenMissing {
                iCloudClient.writePickerShortcuts(normalizedShortcuts)
            }
            return true
        case .invalid:
            return false
        }
    }

    private static func normalizedOrder(
        _ bundleIdentifiers: [String]
    ) -> [String] {
        normalizedIdentifiers(bundleIdentifiers)
    }

    private static func normalizedPickerShortcuts(
        _ assignments: [String: PickerShortcut]
    ) -> [String: PickerShortcut] {
        let sortedAssignments = assignments
            .map { identifier, shortcut in
                (
                    identifier: normalizedIdentifier(identifier),
                    originalIdentifier: identifier,
                    shortcut: shortcut
                )
            }
            .filter {
                !$0.identifier.isEmpty
            }
            .sorted { lhs, rhs in
                if lhs.identifier == rhs.identifier {
                    return lhs.originalIdentifier < rhs.originalIdentifier
                }

                return lhs.identifier < rhs.identifier
            }
        var normalizedAssignments: [String: PickerShortcut] = [:]
        var usedShortcuts = Set<PickerShortcut>()

        for assignment in sortedAssignments {
            guard
                normalizedAssignments[assignment.identifier] == nil,
                usedShortcuts.insert(assignment.shortcut).inserted
            else {
                continue
            }

            normalizedAssignments[assignment.identifier] = assignment.shortcut
        }

        return normalizedAssignments
    }

    private static func normalizedExactHostRoutingRules(
        _ rules: [ExactHostRoutingRule]
    ) -> [ExactHostRoutingRule] {
        var firstIndices: [String: Int] = [:]
        var latestRules: [String: ExactHostRoutingRule] = [:]

        for (index, rule) in rules.enumerated() {
            firstIndices[rule.host, default: index] = firstIndices[rule.host] ?? index
            latestRules[rule.host] = rule
        }

        return latestRules.values.sorted {
            firstIndices[$0.host, default: 0] < firstIndices[$1.host, default: 0]
        }
    }

    private func effectiveVisibleIdentifiers(
        _ discoveredBrowserIdentifiers: [String]
    ) -> [String] {
        let discoveredIdentifiers = Self.normalizedIdentifiers(
            discoveredBrowserIdentifiers
        )
        let hiddenIdentifiers = Set(
            hiddenBrowserIdentifiers.map { $0.lowercased() }
        )
        let visibleIdentifiers = discoveredIdentifiers.filter {
            !hiddenIdentifiers.contains($0.lowercased())
        }

        if visibleIdentifiers.isEmpty, let firstIdentifier = discoveredIdentifiers.first {
            return [firstIdentifier]
        }

        return visibleIdentifiers
    }

    private static func normalizedIdentifiers(
        _ bundleIdentifiers: [String]
    ) -> [String] {
        var seenIdentifiers = Set<String>()

        return bundleIdentifiers.compactMap { identifier in
            let trimmedIdentifier = identifier.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let normalizedIdentifier = trimmedIdentifier.lowercased()

            guard
                !trimmedIdentifier.isEmpty,
                seenIdentifiers.insert(normalizedIdentifier).inserted
            else {
                return nil
            }

            return trimmedIdentifier
        }
    }

    private static func normalizedIdentifier(
        _ bundleIdentifier: String
    ) -> String {
        bundleIdentifier
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
    }
}

// swiftlint:enable file_length type_body_length
