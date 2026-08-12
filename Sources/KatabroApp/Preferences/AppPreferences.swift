struct AppPreferences: Codable, Equatable, Sendable {
    var browserOrder: [String] = []
    var hiddenBrowserIdentifiers: [String] = []
    var hasCompletedOnboarding = false

    private enum CodingKeys: String, CodingKey {
        case browserOrder
        case hiddenBrowserIdentifiers
        case hasCompletedOnboarding
    }

    init(
        browserOrder: [String] = [],
        hiddenBrowserIdentifiers: [String] = [],
        hasCompletedOnboarding: Bool = false
    ) {
        self.browserOrder = browserOrder
        self.hiddenBrowserIdentifiers = hiddenBrowserIdentifiers
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    init(
        from decoder: any Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        browserOrder = try container.decodeIfPresent(
            [String].self,
            forKey: .browserOrder
        ) ?? []
        hiddenBrowserIdentifiers = try container.decodeIfPresent(
            [String].self,
            forKey: .hiddenBrowserIdentifiers
        ) ?? []
        hasCompletedOnboarding = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasCompletedOnboarding
        ) ?? false
    }
}
