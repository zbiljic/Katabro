import Foundation

public struct RoutingRequest: Hashable, Identifiable, Sendable {
    public enum Source: Hashable, Sendable {
        case system
        case commandLine
        case customURL
    }

    public let id: UUID
    public let destination: IncomingURL
    public let source: Source

    public init(
        id: UUID = UUID(),
        destination: IncomingURL,
        source: Source
    ) {
        self.id = id
        self.destination = destination
        self.source = source
    }
}
