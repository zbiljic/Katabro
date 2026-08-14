import AppKit
@testable import Katabro
import KatabroCore
import Testing

@MainActor
@Suite("Workspace browser discovery")
struct WorkspaceBrowserDiscoveryTests {
    @Test("forwards the exact destination URL to Launch Services")
    func forwardsDestinationURL() async throws {
        let destination = try IncomingURL("https://example.com/path?query=value")
        let state = QueryState()
        let discovery = makeDiscovery { receivedURL in
            state.receivedURLs.append(receivedURL)
            return []
        }

        let browsers = try await discovery.browsers(for: destination)

        #expect(state.receivedURLs == [destination.url])
        #expect(browsers.isEmpty)
    }

    @Test("accepts every application location returned by Launch Services")
    func acceptsReturnedApplicationLocations() async throws {
        let systemApplication = application(
            path: "/Applications/Charlie.app",
            name: "Charlie",
            bundleIdentifier: "com.example.charlie"
        )
        let userApplication = application(
            path: "/Users/fixture/Applications/Alpha.app",
            name: "Alpha",
            bundleIdentifier: "com.example.alpha"
        )
        let portableApplication = application(
            path: "/Custom/PortableApps/Bravo.app",
            name: "Bravo",
            bundleIdentifier: "com.example.bravo"
        )
        let discovery = makeDiscovery { _ in
            [systemApplication, userApplication, portableApplication]
        }

        let browsers = try await discovery.browsers(
            for: IncomingURL("https://example.com")
        )

        #expect(browsers.map(\.browser.displayName) == ["Alpha", "Bravo", "Charlie"])
        #expect(
            browsers.map(\.applicationURL) ==
                [
                    userApplication.applicationURL,
                    portableApplication.applicationURL,
                    systemApplication.applicationURL,
                ]
        )
    }

    @Test("keeps the first Launch Services candidate for a duplicate identifier")
    func keepsFirstDuplicateCandidate() async throws {
        let firstApplication = application(
            path: "/Applications/First.app",
            name: "First",
            bundleIdentifier: "com.example.duplicate"
        )
        let secondApplication = application(
            path: "/Custom/PortableApps/Second.app",
            name: "Second",
            bundleIdentifier: "COM.EXAMPLE.DUPLICATE"
        )
        let discovery = makeDiscovery { _ in
            [firstApplication, secondApplication]
        }

        let browsers = try await discovery.browsers(
            for: IncomingURL("https://example.com")
        )

        let browser = try #require(browsers.first)
        #expect(browsers.count == 1)
        #expect(browser.applicationURL == firstApplication.applicationURL)
        #expect(browser.browser.displayName == "First")
    }

    @Test("excludes Katabro and malformed candidates without failing discovery")
    func excludesInvalidCandidates() async throws {
        let katabroApplication = application(
            path: "/Applications/Katabro.app",
            name: "Katabro",
            bundleIdentifier: AppMetadata.bundleIdentifier
        )
        let malformedApplication = application(
            path: "/Custom/Malformed.app",
            name: "Malformed",
            bundleIdentifier: ""
        )
        let validApplication = application(
            path: "/Users/fixture/Applications/Valid Browser.app",
            name: "Valid Browser",
            bundleIdentifier: "com.example.valid-browser"
        )
        let discovery = makeDiscovery { _ in
            [katabroApplication, malformedApplication, validApplication]
        }

        let browsers = try await discovery.browsers(
            for: IncomingURL("https://example.com")
        )

        #expect(browsers.map(\.applicationURL) == [validApplication.applicationURL])
    }
}

@MainActor
private func makeDiscovery(
    applicationsHandler: @escaping WorkspaceBrowserDiscovery.ApplicationsHandler
) -> WorkspaceBrowserDiscovery {
    let image = NSImage(size: NSSize(width: 16, height: 16))

    return WorkspaceBrowserDiscovery(
        applicationsHandler: applicationsHandler
    ) { _ in image }
}

private func application(
    path: String,
    name: String,
    bundleIdentifier: String
) -> WorkspaceBrowserDiscovery.ApplicationCandidate {
    let applicationURL = URL(
        filePath: path,
        directoryHint: .isDirectory
    )

    #expect(applicationURL.deletingPathExtension().lastPathComponent == name)

    return WorkspaceBrowserDiscovery.ApplicationCandidate(
        bundleIdentifier: bundleIdentifier,
        applicationURL: applicationURL
    )
}

@MainActor
private final class QueryState {
    var receivedURLs: [URL] = []
}
