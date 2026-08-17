import AppKit
import CoreServices
import KatabroCore

@MainActor
final class WorkspaceBrowserDiscovery: BrowserDiscovering {
    struct ApplicationCandidate {
        let bundleIdentifier: String
        let applicationURL: URL
    }

    typealias ApplicationsHandler = @MainActor (_ schemes: [String]) -> [ApplicationCandidate]
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
            applicationsHandler: { schemes in
                Self.applicationCandidates(
                    forSchemes: schemes,
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

        for candidate in applicationsHandler(Self.handlerSchemes(for: destination.scheme)) {
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

    static func handlerSchemes(
        for scheme: IncomingURL.Scheme
    ) -> [String] {
        switch scheme {
        case .file:
            [IncomingURL.Scheme.http.rawValue, IncomingURL.Scheme.https.rawValue]
        case .http, .https:
            [scheme.rawValue]
        }
    }

    private static func applicationCandidates(
        forSchemes schemes: [String],
        workspace: NSWorkspace
    ) -> [ApplicationCandidate] {
        // The modern NSWorkspace URL query omits registered handlers located in
        // sandbox-inaccessible directories such as ~/Applications. Keep this
        // deprecated identifier query isolated until AppKit exposes equivalent
        // sandbox-safe handler metadata.
        var identifiers: [String] = []
        var seenIdentifiers: Set<String> = []

        for scheme in schemes {
            let schemeIdentifiers = LSCopyAllHandlersForURLScheme(
                scheme as CFString
            )?.takeRetainedValue() as? [String] ?? []

            for identifier in schemeIdentifiers where seenIdentifiers.insert(identifier.lowercased()).inserted {
                identifiers.append(identifier)
            }
        }

        return identifiers.flatMap { bundleIdentifier in
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
