import AppKit
import KatabroCore

@MainActor
final class WorkspaceBrowserDiscovery: BrowserDiscovering {
    private let policy: RoutingPolicy
    private let workspace: NSWorkspace

    init(
        workspace: NSWorkspace = .shared,
        policy: RoutingPolicy = RoutingPolicy()
    ) {
        self.workspace = workspace
        self.policy = policy
    }

    func browsers(
        for destination: IncomingURL
    ) async throws -> [BrowserApplication] {
        var applicationsByIdentifier: [String: BrowserApplication] = [:]

        for applicationURL in workspace.urlsForApplications(
            toOpen: destination.url
        ) {
            guard let application = application(at: applicationURL) else {
                continue
            }

            let identifier = application.browser.bundleIdentifier.lowercased()

            if applicationsByIdentifier[identifier] == nil {
                applicationsByIdentifier[identifier] = application
            }
        }

        let orderedBrowsers = policy.eligibleBrowsers(
            from: applicationsByIdentifier.values.map(\.browser)
        )

        return orderedBrowsers.compactMap { browser in
            applicationsByIdentifier[browser.bundleIdentifier.lowercased()]
        }
    }

    private func application(
        at applicationURL: URL
    ) -> BrowserApplication? {
        guard
            let bundle = Bundle(url: applicationURL),
            let bundleIdentifier = bundle.bundleIdentifier?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !bundleIdentifier.isEmpty
        else {
            return nil
        }

        let displayName = localizedName(
            for: bundle,
            at: applicationURL
        )

        guard !displayName.isEmpty else {
            return nil
        }

        return BrowserApplication(
            browser: Browser(
                bundleIdentifier: bundleIdentifier,
                displayName: displayName
            ),
            applicationURL: applicationURL,
            icon: workspace.icon(forFile: applicationURL.path)
        )
    }

    private func localizedName(
        for bundle: Bundle,
        at applicationURL: URL
    ) -> String {
        let displayName = bundle.object(
            forInfoDictionaryKey: "CFBundleDisplayName"
        ) as? String
        let bundleName = bundle.object(
            forInfoDictionaryKey: "CFBundleName"
        ) as? String

        return (displayName ?? bundleName ?? applicationURL.deletingPathExtension().lastPathComponent)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
