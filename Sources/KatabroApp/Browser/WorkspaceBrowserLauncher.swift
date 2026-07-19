import AppKit
import KatabroCore

@MainActor
final class WorkspaceBrowserLauncher: BrowserLaunching {
    private let workspace: NSWorkspace

    init(
        workspace: NSWorkspace = .shared
    ) {
        self.workspace = workspace
    }

    func open(
        _ destination: IncomingURL,
        with browser: BrowserApplication
    ) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = true
        configuration.allowsRunningApplicationSubstitution = true

        _ = try await workspace.open(
            [destination.url],
            withApplicationAt: browser.applicationURL,
            configuration: configuration
        )
    }
}
