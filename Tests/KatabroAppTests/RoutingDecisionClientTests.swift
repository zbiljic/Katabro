@testable import Katabro
import KatabroCore
import Testing

@MainActor
@Suite("Routing decision client")
struct RoutingDecisionClientTests {
    @Test("opens the first matching exact-host target")
    func opensFirstMatch() async throws {
        let rules = try [
            #require(
                ExactHostRoutingRule(
                    host: "EXAMPLE.com.",
                    targetIdentifier: "com.example.browser:profile:Mixed Case"
                )
            ),
            #require(
                ExactHostRoutingRule(
                    host: "example.com",
                    targetIdentifier: "later-target"
                )
            ),
        ]
        let request = try RoutingRequest(
            destination: IncomingURL("https://example.COM/path?q=1"),
            source: .system
        )

        let decision = await RoutingDecisionClient.exactHostRules.decision(
            for: request,
            rules: rules
        )

        #expect(
            decision == .open(
                targetIdentifier: "com.example.browser:profile:Mixed Case"
            )
        )
    }

    @Test(
        "asks when no exact host matches",
        arguments: [
            "https://www.example.com",
            "https://sub.example.com",
            "https://example.net",
        ]
    )
    func asksForNonMatch(rawURL: String) async throws {
        let rule = try #require(
            ExactHostRoutingRule(
                host: "example.com",
                targetIdentifier: "target"
            )
        )
        let request = try RoutingRequest(
            destination: IncomingURL(rawURL),
            source: .system
        )

        let decision = await RoutingDecisionClient.exactHostRules.decision(
            for: request,
            rules: [rule]
        )

        #expect(decision == .ask)
    }
}
