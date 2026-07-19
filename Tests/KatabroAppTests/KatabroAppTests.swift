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
}
