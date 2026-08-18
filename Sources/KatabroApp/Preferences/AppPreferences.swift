import KatabroCore

struct AppPreferences: Codable, Equatable, Sendable {
    var browserOrder: [String] = []
    var hiddenBrowserIdentifiers: [String] = []
    var pickerShortcuts: [String: PickerShortcut] = [:]
    var hasCompletedOnboarding = false
    var exactHostRoutingRules: [ExactHostRoutingRule] = []
    var pickerPreferences = BrowserPickerPreferences()

    private enum CodingKeys: String, CodingKey {
        case browserOrder
        case hiddenBrowserIdentifiers
        case pickerShortcuts
        case hasCompletedOnboarding
        case exactHostRoutingRules
        case pickerPreferences
    }

    init(
        browserOrder: [String] = [],
        hiddenBrowserIdentifiers: [String] = [],
        pickerShortcuts: [String: PickerShortcut] = [:],
        hasCompletedOnboarding: Bool = false,
        exactHostRoutingRules: [ExactHostRoutingRule] = [],
        pickerPreferences: BrowserPickerPreferences = BrowserPickerPreferences()
    ) {
        self.browserOrder = browserOrder
        self.hiddenBrowserIdentifiers = hiddenBrowserIdentifiers
        self.pickerShortcuts = pickerShortcuts
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.exactHostRoutingRules = exactHostRoutingRules
        self.pickerPreferences = pickerPreferences
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
        exactHostRoutingRules = try container.decodeLossyArrayIfPresent(
            ExactHostRoutingRule.self,
            forKey: .exactHostRoutingRules
        )
        pickerPreferences = (try? container.decode(
            BrowserPickerPreferences.self,
            forKey: .pickerPreferences
        )) ?? BrowserPickerPreferences()
    }
}

private extension KeyedDecodingContainer {
    struct LossyElement<Element: Decodable>: Decodable {
        let value: Element?

        init(from decoder: any Decoder) throws {
            value = try? Element(from: decoder)
        }
    }

    func decodeLossyArrayIfPresent<Element: Decodable>(
        _: Element.Type,
        forKey key: Key
    ) throws -> [Element] {
        guard contains(key) else {
            return []
        }

        return try decode([LossyElement<Element>].self, forKey: key)
            .compactMap(\.value)
    }
}
