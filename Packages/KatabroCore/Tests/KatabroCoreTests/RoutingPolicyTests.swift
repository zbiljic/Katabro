@testable import KatabroCore
import Testing

@Suite("Browser routing policy")
struct RoutingPolicyTests {
    @Test("removes Katabro, invalid entries, and duplicate browsers")
    func filtersIneligibleBrowsers() {
        let browsers = [
            Browser(
                bundleIdentifier: "com.apple.Safari",
                displayName: "Safari"
            ),
            Browser(
                bundleIdentifier: "COM.APPLE.SAFARI",
                displayName: "Safari duplicate"
            ),
            Browser(
                bundleIdentifier: KatabroCore.appBundleIdentifier,
                displayName: "Katabro"
            ),
            Browser(
                bundleIdentifier: "",
                displayName: "Missing identifier"
            ),
            Browser(
                bundleIdentifier: "com.example.missing-name",
                displayName: ""
            ),
        ]

        let eligibleBrowsers = RoutingPolicy().eligibleBrowsers(from: browsers)

        #expect(
            eligibleBrowsers == [
                Browser(
                    bundleIdentifier: "com.apple.Safari",
                    displayName: "Safari"
                ),
            ]
        )
    }

    @Test("sorts browsers deterministically by name and bundle identifier")
    func sortsBrowsers() {
        let browsers = [
            Browser(
                bundleIdentifier: "com.example.zeta",
                displayName: "Browser"
            ),
            Browser(
                bundleIdentifier: "com.example.chrome",
                displayName: "Chrome"
            ),
            Browser(
                bundleIdentifier: "com.example.alpha",
                displayName: "browser"
            ),
            Browser(
                bundleIdentifier: "com.example.arc",
                displayName: "Arc"
            ),
        ]

        let eligibleBrowsers = RoutingPolicy().eligibleBrowsers(from: browsers)

        #expect(
            eligibleBrowsers.map(\.bundleIdentifier) == [
                "com.example.arc",
                "com.example.alpha",
                "com.example.zeta",
                "com.example.chrome",
            ]
        )
    }

    @Test("compares the application identifier case-insensitively")
    func excludesApplicationCaseInsensitively() {
        let browser = Browser(
            bundleIdentifier: KatabroCore.appBundleIdentifier.uppercased(),
            displayName: "Katabro"
        )

        #expect(RoutingPolicy().eligibleBrowsers(from: [browser]).isEmpty)
    }
}
