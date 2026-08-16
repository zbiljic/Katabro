import Foundation
import KatabroCore

/// The deliberately small, versioned representation shared by folder
/// transports.  Do not add local-only preferences to this type.
struct BrowserSettingsSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let browserOrder: [String]
    let pickerShortcuts: [String: PickerShortcut]
    let exactHostRoutingRules: [ExactHostRoutingRule]

    init(
        browserOrder: [String],
        pickerShortcuts: [String: PickerShortcut],
        exactHostRoutingRules: [ExactHostRoutingRule],
        schemaVersion: Int = Self.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.browserOrder = browserOrder
        self.pickerShortcuts = pickerShortcuts
        self.exactHostRoutingRules = exactHostRoutingRules
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case order
        case shortcuts
        case routingRules
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        guard version == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .version,
                in: container,
                debugDescription: "Unsupported settings schema version."
            )
        }

        // All three fields are required.  In particular, do not use decodeIfPresent
        // here: a missing field must never clear a local field accidentally.
        try self.init(
            browserOrder: container.decode([String].self, forKey: .order),
            pickerShortcuts: container.decode(
                [String: PickerShortcut].self,
                forKey: .shortcuts
            ),
            exactHostRoutingRules: container.decode([WireRule].self, forKey: .routingRules).map(\.rule),
            schemaVersion: version
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .version)
        try container.encode(browserOrder, forKey: .order)
        try container.encode(pickerShortcuts, forKey: .shortcuts)
        try container.encode(exactHostRoutingRules.map(WireRule.init), forKey: .routingRules)
    }

    func encodedData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self) + Data([0x0A])
    }

    private struct WireRule: Codable {
        let rule: ExactHostRoutingRule

        init(_ rule: ExactHostRoutingRule) {
            self.rule = rule
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKey.self)
            let supportedKeys = Set(["matchHost", "targetIdentifier"])
            guard
                Set(container.allKeys.map(\.stringValue)) == supportedKeys,
                let matchHostKey = container.allKeys.first(where: { $0.stringValue == "matchHost" }),
                let targetIdentifierKey = container.allKeys.first(where: { $0.stringValue == "targetIdentifier" })
            else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unsupported exact-host routing rule keys."
                    )
                )
            }

            let matchHost = try container.decode(String.self, forKey: matchHostKey)
            let targetIdentifier = try container.decode(String.self, forKey: targetIdentifierKey)
            guard let rule = ExactHostRoutingRule(host: matchHost, targetIdentifier: targetIdentifier) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Invalid exact-host routing rule."
                    )
                )
            }
            self.rule = rule
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: WireRuleCodingKeys.self)
            try container.encode(rule.host, forKey: .matchHost)
            try container.encode(rule.targetIdentifier, forKey: .targetIdentifier)
        }
    }

    private enum WireRuleCodingKeys: String, CodingKey {
        case matchHost
        case targetIdentifier
    }

    private struct DynamicCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int? = nil

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue _: Int) {
            nil
        }
    }
}
