import Foundation

public struct ExactHostRoutingRule: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let host: String
    public let targetIdentifier: String

    public var id: String {
        host
    }

    public init?(
        host: String,
        targetIdentifier: String
    ) {
        guard
            let normalizedHost = Self.normalizedHost(host),
            !targetIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        self.host = normalizedHost
        self.targetIdentifier = targetIdentifier
    }

    public static func normalizedHost(
        _ rawValue: String
    ) -> String? {
        var host = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if host.hasSuffix(".") {
            host.removeLast()
        }

        guard !host.isEmpty else {
            return nil
        }

        return host.lowercased()
    }

    public func matches(
        _ destination: IncomingURL
    ) -> Bool {
        guard let destinationHost = destination.url.host() else {
            return false
        }

        return Self.normalizedHost(destinationHost) == host
    }

    private enum CodingKeys: String, CodingKey {
        case host
        case targetIdentifier
    }

    public init(
        from decoder: any Decoder
    ) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let host = try container.decode(String.self, forKey: .host)
        let targetIdentifier = try container.decode(
            String.self,
            forKey: .targetIdentifier
        )

        guard
            let rule = Self(
                host: host,
                targetIdentifier: targetIdentifier
            )
        else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid exact-host routing rule."
                )
            )
        }

        self = rule
    }
}
