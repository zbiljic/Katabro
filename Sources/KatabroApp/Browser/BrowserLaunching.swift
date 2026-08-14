import KatabroCore

@MainActor
protocol BrowserLaunching {
    func open(
        _ destination: IncomingURL,
        with target: BrowserLaunchTarget
    ) async throws
}
