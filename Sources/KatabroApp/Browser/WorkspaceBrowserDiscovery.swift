import AppKit
import CoreServices
import KatabroCore

@MainActor
final class WorkspaceBrowserDiscovery: BrowserDiscovering {
    struct ApplicationCandidate {
        let bundleIdentifier: String
        let applicationURL: URL
    }

    typealias ApplicationsHandler = @MainActor (_ destinationURL: URL) -> [ApplicationCandidate]
    typealias IconHandler = @MainActor (_ applicationPath: String) -> NSImage

    private let applicationsHandler: ApplicationsHandler
    private let iconHandler: IconHandler
    private let policy: RoutingPolicy

    convenience init(
        workspace: NSWorkspace = .shared,
        policy: RoutingPolicy = RoutingPolicy()
    ) {
        self.init(
            policy: policy,
            applicationsHandler: { destinationURL in
                Self.applicationCandidates(
                    for: destinationURL,
                    workspace: workspace
                )
            },
            iconHandler: { applicationPath in
                workspace.icon(forFile: applicationPath)
            }
        )
    }

    init(
        policy: RoutingPolicy = RoutingPolicy(),
        applicationsHandler: @escaping ApplicationsHandler,
        iconHandler: @escaping IconHandler
    ) {
        self.applicationsHandler = applicationsHandler
        self.iconHandler = iconHandler
        self.policy = policy
    }

    func browsers(
        for destination: IncomingURL
    ) async throws -> [BrowserApplication] {
        var applicationsByIdentifier: [String: BrowserApplication] = [:]

        for candidate in applicationsHandler(destination.url) {
            guard let application = application(from: candidate) else {
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
        from candidate: ApplicationCandidate
    ) -> BrowserApplication? {
        let bundleIdentifier = candidate.bundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = candidate.applicationURL
            .deletingPathExtension()
            .lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            !bundleIdentifier.isEmpty,
            !displayName.isEmpty
        else {
            return nil
        }

        return BrowserApplication(
            browser: Browser(
                bundleIdentifier: bundleIdentifier,
                displayName: displayName
            ),
            applicationURL: candidate.applicationURL,
            icon: iconHandler(candidate.applicationURL.path)
        )
    }

    private static func applicationCandidates(
        for destinationURL: URL,
        workspace: NSWorkspace
    ) -> [ApplicationCandidate] {
        // The modern NSWorkspace URL query omits registered handlers located in
        // sandbox-inaccessible directories such as ~/Applications. Keep this
        // deprecated identifier query isolated until AppKit exposes equivalent
        // sandbox-safe handler metadata.
        guard
            let scheme = destinationURL.scheme,
            let handlerIdentifiers = LSCopyAllHandlersForURLScheme(
                scheme as CFString
            )?.takeRetainedValue() as? [String]
        else {
            return []
        }

        return handlerIdentifiers.flatMap { bundleIdentifier in
            workspace
                .urlsForApplications(
                    withBundleIdentifier: bundleIdentifier
                )
                .map { applicationURL in
                    ApplicationCandidate(
                        bundleIdentifier: bundleIdentifier,
                        applicationURL: applicationURL
                    )
                }
        }
    }
}
