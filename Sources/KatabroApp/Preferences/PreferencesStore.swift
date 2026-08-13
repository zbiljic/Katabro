import Foundation
import Observation

// Visibility and iCloud reconciliation intentionally share the aggregate preference owner.
// swiftlint:disable file_length type_body_length
@MainActor
@Observable
final class PreferencesStore {
    enum ICloudSyncStatus: Equatable, Sendable {
        case available
        case localOnly
        case invalidCloudValue
    }

    private enum Key {
        static let preferences = "app.preferences"
    }

    private enum UpdateOrigin: Equatable {
        case user
        case remote
        case local
    }

    @ObservationIgnored private let save: (AppPreferences) -> Void
    @ObservationIgnored private let iCloudClient: ICloudPreferencesClient?

    private(set) var preferences: AppPreferences
    private(set) var iCloudSyncStatus: ICloudSyncStatus

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

    init(
        initialPreferences: AppPreferences = AppPreferences(),
        initialSyncStatus: ICloudSyncStatus = .localOnly,
        iCloudClient: ICloudPreferencesClient? = nil,
        save: @escaping (AppPreferences) -> Void = { _ in }
    ) {
        var normalizedPreferences = initialPreferences
        normalizedPreferences.hiddenBrowserIdentifiers = Self.normalizedIdentifiers(
            initialPreferences.hiddenBrowserIdentifiers
        )
        normalizedPreferences.pickerShortcuts = Self.normalizedPickerShortcuts(
            initialPreferences.pickerShortcuts
        )
        preferences = normalizedPreferences
        iCloudSyncStatus = initialSyncStatus
        self.iCloudClient = iCloudClient
        self.save = save
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
        defaultPreferences: AppPreferences = AppPreferences()
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
            iCloudClient: iCloudClient
        ) { preferences in
            guard let data = try? JSONEncoder().encode(preferences) else {
                return
            }

            userDefaults.set(
                data,
                forKey: Key.preferences
            )
        }
        if iCloudClient != nil {
            store.startICloudSync()
        }
        return store
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
            origin: .local
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
            origin: .user
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

    private func update(
        _ preferences: AppPreferences,
        origin: UpdateOrigin
    ) {
        guard self.preferences != preferences else {
            return
        }

        self.preferences = preferences
        save(preferences)

        if origin == .user, iCloudSyncStatus == .available {
            iCloudClient?.writeBrowserOrder(preferences.browserOrder)
        }
    }

    func startICloudSync() {
        guard let iCloudClient else {
            return
        }

        let didStart = iCloudClient.start { [weak self] event in
            self?.handleICloudEvent(event)
        }

        guard didStart else {
            iCloudSyncStatus = .localOnly
            return
        }

        applyCloudBrowserOrder(
            seedWhenMissing: true
        )
    }

    private func handleICloudEvent(
        _ event: ICloudPreferencesClient.Event
    ) {
        switch event {
        case let .changed(reason, keys):
            let ignoresBrowserOrder = reason == .serverChange
                && keys?.contains(ICloudPreferencesClient.browserOrderKey) == false

            if ignoresBrowserOrder {
                return
            }

            applyCloudBrowserOrder(
                seedWhenMissing: false
            )
        case .quotaViolation:
            iCloudSyncStatus = .localOnly
        }
    }

    private func applyCloudBrowserOrder(
        seedWhenMissing: Bool
    ) {
        guard let iCloudClient else {
            return
        }

        switch iCloudClient.readBrowserOrder() {
        case let .value(browserOrder):
            var preferences = preferences
            preferences.browserOrder = Self.normalizedOrder(browserOrder)
            update(
                preferences,
                origin: .remote
            )
            iCloudSyncStatus = .available
        case .missing:
            let normalizedOrder = Self.normalizedOrder(browserOrder)
            var preferences = preferences
            preferences.browserOrder = normalizedOrder
            update(
                preferences,
                origin: .remote
            )
            iCloudSyncStatus = .available

            if seedWhenMissing {
                iCloudClient.writeBrowserOrder(normalizedOrder)
            }
        case .invalid:
            iCloudSyncStatus = .invalidCloudValue
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
