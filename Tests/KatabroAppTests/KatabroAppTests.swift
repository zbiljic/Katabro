@testable import Katabro
import Testing

@Suite("Katabro application")
struct KatabroAppTests {
    @Test("uses the registered bundle identifier")
    func bundleIdentifier() {
        #expect(AppMetadata.bundleIdentifier == "com.zbiljic.katabro")
    }
}
