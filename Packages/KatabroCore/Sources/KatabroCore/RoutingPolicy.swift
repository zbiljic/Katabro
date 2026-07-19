public struct RoutingPolicy: Sendable {
    public let appBundleIdentifier: String

    public init(
        appBundleIdentifier: String = KatabroCore.appBundleIdentifier
    ) {
        self.appBundleIdentifier = appBundleIdentifier
    }

    public func eligibleBrowsers(
        from browsers: [Browser]
    ) -> [Browser] {
        let normalizedAppIdentifier = appBundleIdentifier.lowercased()
        var seenIdentifiers = Set<String>()

        return browsers
            .filter { browser in
                let identifier = browser.bundleIdentifier.lowercased()

                guard
                    !identifier.isEmpty,
                    identifier != normalizedAppIdentifier,
                    !browser.displayName.isEmpty
                else {
                    return false
                }

                return seenIdentifiers.insert(identifier).inserted
            }
            .sorted(by: Self.browserPrecedes)
    }

    private static func browserPrecedes(
        _ first: Browser,
        _ second: Browser
    ) -> Bool {
        let firstName = first.displayName.lowercased()
        let secondName = second.displayName.lowercased()

        if firstName == secondName {
            return first.bundleIdentifier.lowercased() < second.bundleIdentifier.lowercased()
        }

        return firstName < secondName
    }
}
