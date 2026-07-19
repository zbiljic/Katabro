import KatabroCore

@MainActor
protocol BrowserDiscovering {
    func browsers(
        for destination: IncomingURL
    ) async throws -> [BrowserApplication]
}
