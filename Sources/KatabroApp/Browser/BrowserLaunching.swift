import KatabroCore

@MainActor
protocol BrowserLaunching {
    func open(
        _ destination: IncomingURL,
        with browser: BrowserApplication
    ) async throws
}
