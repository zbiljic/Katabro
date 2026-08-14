import AppKit
import KatabroCore

@MainActor
final class WorkspaceBrowserLauncher: BrowserLaunching {
    private let workspace: NSWorkspace
    private let userScriptBridge: UserScriptBridge

    init(
        workspace: NSWorkspace = .shared,
        userScriptBridge: UserScriptBridge
    ) {
        self.workspace = workspace
        self.userScriptBridge = userScriptBridge
    }

    func open(
        _ destination: IncomingURL,
        with target: BrowserLaunchTarget
    ) async throws {
        guard target.requiresUserScript else {
            try await openNormally(
                destination,
                with: target.browser
            )
            return
        }

        try await userScriptBridge.execute(
            arguments: [
                "--new",
                "-a",
                target.browser.applicationURL.path,
                "--args",
            ] + target.browserArguments(for: destination)
        )
    }

    private func openNormally(
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
