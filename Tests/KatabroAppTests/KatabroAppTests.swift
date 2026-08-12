import Foundation
@testable import Katabro
import KatabroCore
import Testing

@Suite("Katabro application")
struct KatabroAppTests {
    @Test("uses the registered bundle identifier")
    func bundleIdentifier() {
        #expect(Bundle.main.bundleIdentifier == KatabroCore.appBundleIdentifier)
        #expect(AppMetadata.bundleIdentifier == KatabroCore.appBundleIdentifier)
    }

    @Test("exposes bundle metadata for the About pane")
    func aboutBundleMetadata() {
        #expect(!AppMetadata.shortVersion.isEmpty)
        #expect(!AppMetadata.build.isEmpty)
        #expect(!AppMetadata.versionDescription.isEmpty)
        #expect(AppMetadata.versionDescription.contains(AppMetadata.shortVersion))
        #expect(AppMetadata.versionDescription.contains(AppMetadata.build))
        #expect(!AppMetadata.copyright.isEmpty)
    }

    @Test("uses the public project links in the About pane")
    func aboutURLs() {
        #expect(
            AppMetadata.repositoryURL.absoluteString ==
                "https://github.com/zbiljic/Katabro"
        )
        #expect(
            AppMetadata.issuesURL.absoluteString ==
                "https://github.com/zbiljic/Katabro/issues"
        )
        #expect(
            AppMetadata.licenseURL.absoluteString ==
                "https://github.com/zbiljic/Katabro/blob/main/LICENSE"
        )
    }
}
