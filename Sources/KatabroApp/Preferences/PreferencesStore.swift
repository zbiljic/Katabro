import Foundation
import Observation

@MainActor
@Observable
final class PreferencesStore {
    private enum Key {
        static let preferences = "app.preferences"
    }

    @ObservationIgnored private let save: (AppPreferences) -> Void

    private(set) var preferences: AppPreferences

    var browserOrder: [String] {
        preferences.browserOrder
    }

    init(
        initialPreferences: AppPreferences = AppPreferences(),
        save: @escaping (AppPreferences) -> Void = { _ in }
    ) {
        preferences = initialPreferences
        self.save = save
    }

    static func live(
        userDefaults: UserDefaults = .standard
    ) -> PreferencesStore {
        let data = userDefaults.data(
            forKey: Key.preferences
        )
        let preferences = data.flatMap { data in
            try? JSONDecoder().decode(
                AppPreferences.self,
                from: data
            )
        } ?? AppPreferences()

        return Self(initialPreferences: preferences) { preferences in
            guard let data = try? JSONEncoder().encode(preferences) else {
                return
            }

            userDefaults.set(
                data,
                forKey: Key.preferences
            )
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

        setBrowserOrder(
            orderedBrowsers.map(\.browser.bundleIdentifier)
        )

        return orderedBrowsers
    }

    func setBrowserOrder(
        _ bundleIdentifiers: [String]
    ) {
        var seenIdentifiers = Set<String>()
        let normalizedOrder: [String] = bundleIdentifiers.compactMap { identifier in
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

        update(
            AppPreferences(
                browserOrder: normalizedOrder
            )
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

    private func update(
        _ preferences: AppPreferences
    ) {
        guard self.preferences != preferences else {
            return
        }

        self.preferences = preferences
        save(preferences)
    }
}
