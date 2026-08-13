struct AppPreferences: Codable, Equatable, Sendable {
    var browserOrder: [String] = []
    var hiddenBrowserIdentifiers: [String] = []
    var pickerShortcuts: [String: PickerShortcut] = [:]
    var hasCompletedOnboarding = false

    private enum CodingKeys: String, CodingKey {
        case browserOrder
        case hiddenBrowserIdentifiers
        case pickerShortcuts
        case hasCompletedOnboarding
    }

    init(
        browserOrder: [String] = [],
        hiddenBrowserIdentifiers: [String] = [],
        pickerShortcuts: [String: PickerShortcut] = [:],
        hasCompletedOnboarding: Bool = false
    ) {
        self.browserOrder = browserOrder
        self.hiddenBrowserIdentifiers = hiddenBrowserIdentifiers
        self.pickerShortcuts = pickerShortcuts
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
        let decodedShortcuts = try? container.decode(
            [String: String].self,
            forKey: .pickerShortcuts
        )
        pickerShortcuts = (decodedShortcuts ?? [:]).reduce(into: [:]) { result, entry in
            if let shortcut = PickerShortcut(entry.value) {
                result[entry.key] = shortcut
            }
        }
        hasCompletedOnboarding = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasCompletedOnboarding
        ) ?? false
    }
}
