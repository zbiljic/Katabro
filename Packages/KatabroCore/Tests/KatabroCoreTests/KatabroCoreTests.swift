@testable import KatabroCore
import Testing

@Suite("KatabroCore")
struct KatabroCoreTests {
    @Test("exposes the application bundle identifier")
    func appBundleIdentifier() {
        #expect(KatabroCore.appBundleIdentifier == "com.zbiljic.katabro")
    }
}
