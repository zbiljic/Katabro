public struct Browser: Codable, Hashable, Identifiable, Sendable {
    public var id: String {
        bundleIdentifier
    }

    public let bundleIdentifier: String
    public let displayName: String

    public init(
        bundleIdentifier: String,
        displayName: String
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }
}
