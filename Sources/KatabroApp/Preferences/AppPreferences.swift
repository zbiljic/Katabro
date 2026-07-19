struct AppPreferences: Codable, Equatable, Sendable {
    var browserOrder: [String] = []
    var hasCompletedOnboarding = false

    private enum CodingKeys: String, CodingKey {
        case browserOrder
        case hasCompletedOnboarding
    }

    init(
        browserOrder: [String] = [],
        hasCompletedOnboarding: Bool = false
    ) {
        self.browserOrder = browserOrder
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
        hasCompletedOnboarding = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasCompletedOnboarding
        ) ?? false
    }
}
