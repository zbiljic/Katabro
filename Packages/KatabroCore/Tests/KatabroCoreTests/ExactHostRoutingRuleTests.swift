import Foundation
@testable import KatabroCore
import Testing

@Suite("Exact-host routing rules")
struct ExactHostRoutingRuleTests {
    @Test("normalizes hosts and matches exactly")
    func normalizesAndMatchesExactly() throws {
        let rule = try #require(
            ExactHostRoutingRule(
                host: "  EXAMPLE.com.\n",
                targetIdentifier: "com.example.Browser:profile:Work Profile "
            )
        )

        #expect(rule.host == "example.com")
        #expect(rule.id == "example.com")
        #expect(rule.targetIdentifier == "com.example.Browser:profile:Work Profile ")
        #expect(try rule.matches(IncomingURL("https://EXAMPLE.COM/path?q=1")))
        #expect(try !rule.matches(IncomingURL("https://www.example.com")))
        #expect(try !rule.matches(IncomingURL("https://sub.example.com")))
        #expect(try !rule.matches(IncomingURL("https://example.net")))
    }

    @Test("removes at most one trailing dot")
    func removesAtMostOneTrailingDot() {
        #expect(ExactHostRoutingRule.normalizedHost("Example.COM.") == "example.com")
        #expect(ExactHostRoutingRule.normalizedHost("Example.COM..") == "example.com.")
    }

    @Test("rejects empty host and target")
    func rejectsEmptyValues() {
        #expect(ExactHostRoutingRule(host: " . ", targetIdentifier: "target") == nil)
        #expect(ExactHostRoutingRule(host: "example.com", targetIdentifier: " \n") == nil)
    }

    @Test("round trips through Codable")
    func codableRoundTrip() throws {
        let rule = try #require(
            ExactHostRoutingRule(
                host: "Example.com.",
                targetIdentifier: "com.example.browser:profile:Mixed Case"
            )
        )
        let decoded = try JSONDecoder().decode(
            ExactHostRoutingRule.self,
            from: JSONEncoder().encode(rule)
        )

        #expect(decoded == rule)
    }

    @Test("decoding validates stored values")
    func decodingValidatesValues() {
        let data = Data(#"{"host":"","targetIdentifier":"target"}"#.utf8)

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(ExactHostRoutingRule.self, from: data)
        }
    }
}
