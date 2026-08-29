import Foundation
@testable import Katabro
import KatabroCore
import Testing

@MainActor
@Suite("Routing decision log store")
struct RoutingDecisionLogStoreTests {
    @Test("starts empty and preserves arrival order")
    func initialStateAndArrivalOrder() throws {
        let store = RoutingDecisionLogStore()
        #expect(store.entries.isEmpty)

        let first = try request(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
            url: "https://first.example/private",
            source: .system
        )
        let second = try request(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002")),
            url: "https://second.example/secret",
            source: .commandLine
        )

        store.receive(first, at: Date(timeIntervalSince1970: 10))
        store.receive(second, at: Date(timeIntervalSince1970: 20))

        #expect(store.entries.map(\.id) == [first.id, second.id])
        #expect(store.entries.map(\.receivedAt) == [
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 20),
        ])
    }

    @Test("duplicate receive is a no-op")
    func duplicateReceive() throws {
        let store = RoutingDecisionLogStore()
        let duplicate = try request(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000003")),
            url: "https://duplicate.example/first",
            source: .system
        )

        store.receive(duplicate, at: Date(timeIntervalSince1970: 10))
        store.updateResult(for: duplicate.id, to: .copiedLink)
        store.receive(duplicate, at: Date(timeIntervalSince1970: 20))

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.receivedAt == Date(timeIntervalSince1970: 10))
        #expect(store.entries.first?.result == .copiedLink)
    }

    @Test("supports every decision transition")
    func decisionTransitions() throws {
        let store = RoutingDecisionLogStore()
        let route = try request(url: "https://decision.example/private")
        store.receive(route)

        #expect(store.entries.first?.decision == .evaluating)

        store.updateDecision(
            for: route.id,
            to: .exactHostRule(
                targetDisplayLabel: "Private Window — Example Browser"
            )
        )
        #expect(
            store.entries.first?.decision == .exactHostRule(
                targetDisplayLabel: "Private Window — Example Browser"
            )
        )

        store.updateDecision(
            for: route.id,
            to: .browserPicker(reason: .noMatchingRule)
        )
        #expect(
            store.entries.first?.decision == .browserPicker(
                reason: .noMatchingRule
            )
        )

        store.updateDecision(
            for: route.id,
            to: .browserPicker(reason: .savedTargetUnavailable)
        )
        #expect(
            store.entries.first?.decision == .browserPicker(
                reason: .savedTargetUnavailable
            )
        )
    }

    @Test("supports every explicit result transition")
    func resultTransitions() throws {
        let store = RoutingDecisionLogStore()
        let route = try request(url: "https://result.example/private")
        store.receive(route)

        #expect(store.entries.first?.result == .pending)

        let results: [RoutingDecisionLogEntry.Result] = [
            .opened(
                targetIdentifier: "opaque:target:identifier",
                targetDisplayLabel: "Work — Example Browser"
            ),
            .copiedLink,
            .cancelled,
            .failed(.routing),
            .failed(.copyingLink),
            .failed(.openingTarget),
        ]

        for result in results {
            store.updateResult(for: route.id, to: result)
            #expect(store.entries.first?.result == result)
        }
    }

    @Test("finish changes only a pending result")
    func finishOnlyIfPending() throws {
        let store = RoutingDecisionLogStore()
        let pending = try request(url: "https://pending.example")
        let opened = try request(url: "https://opened.example")
        let failed = try request(url: "https://failed.example")
        store.receive(pending)
        store.receive(opened)
        store.receive(failed)
        store.updateResult(
            for: opened.id,
            to: .opened(
                targetIdentifier: "opaque-opened",
                targetDisplayLabel: "Example Browser"
            )
        )
        store.updateResult(for: failed.id, to: .failed(.routing))

        for route in [pending, opened, failed] {
            store.finishIfPending(requestID: route.id)
        }

        #expect(store.entries[0].result == .cancelled)
        #expect(
            store.entries[1].result == .opened(
                targetIdentifier: "opaque-opened",
                targetDisplayLabel: "Example Browser"
            )
        )
        #expect(store.entries[2].result == .failed(.routing))
    }

    @Test("uses fixed decision, result, and failure summaries")
    func fixedSummaries() {
        #expect(RoutingDecisionLogEntry.Decision.evaluating.summary == "Evaluating")
        #expect(
            RoutingDecisionLogEntry.Decision.browserPicker(
                reason: .noMatchingRule
            ).summary == "Browser picker — No matching rule"
        )
        #expect(
            RoutingDecisionLogEntry.Decision.browserPicker(
                reason: .savedTargetUnavailable
            ).summary == "Browser picker — Saved target unavailable"
        )
        #expect(RoutingDecisionLogEntry.Result.pending.summary == "Pending")
        #expect(RoutingDecisionLogEntry.Result.copiedLink.summary == "Copied link")
        #expect(RoutingDecisionLogEntry.Result.cancelled.summary == "Cancelled")
        #expect(RoutingDecisionLogEntry.Failure.routing.summary == "Routing failed")
        #expect(RoutingDecisionLogEntry.Failure.copyingLink.summary == "Couldn’t copy link")
        #expect(RoutingDecisionLogEntry.Failure.openingTarget.summary == "Couldn’t open target")
    }

    @Test("evicts oldest entries beyond exactly fifty")
    func boundedCapacity() throws {
        let store = RoutingDecisionLogStore()
        var requestIDs: [UUID] = []

        for index in 0 ... RoutingDecisionLogStore.capacity {
            let route = try request(
                url: "https://host\(index).example/private"
            )
            requestIDs.append(route.id)
            store.receive(route)
        }

        #expect(store.entries.count == RoutingDecisionLogStore.capacity)
        #expect(store.entries.map(\.id) == Array(requestIDs.dropFirst()))

        store.updateResult(for: requestIDs[0], to: .copiedLink)
        #expect(!store.entries.contains { $0.id == requestIDs[0] })
    }

    @Test("clear removes records and later updates cannot resurrect them")
    func clearAndNoResurrection() throws {
        let store = RoutingDecisionLogStore()
        let route = try request(url: "https://clear.example/private")
        store.receive(route)
        store.clear()

        store.updateDecision(
            for: route.id,
            to: .browserPicker(reason: .noMatchingRule)
        )
        store.updateResult(for: route.id, to: .copiedLink)
        store.finishIfPending(requestID: route.id)

        #expect(store.entries.isEmpty)
    }

    @Test("discards web secrets and normalizes the host")
    func webPrivacyBoundary() throws {
        let store = RoutingDecisionLogStore()
        let route = try request(
            url: "https://user:password@Sub.Example.COM:8443/private/token?secret=yes#fragment"
        )
        store.receive(route)

        let entry = try #require(store.entries.first)
        let reflectedEntry = String(reflecting: entry)
        #expect(entry.destinationKind == .web)
        #expect(entry.webScheme == .https)
        #expect(entry.normalizedHost == "sub.example.com")
        #expect(entry.destinationDisplayName == "sub.example.com")
        #expect(!reflectedEntry.contains("password"))
        #expect(!reflectedEntry.contains("private/token"))
        #expect(!reflectedEntry.contains("secret=yes"))
        #expect(!reflectedEntry.contains("fragment"))
        #expect(!reflectedEntry.contains("8443"))
    }

    @Test("discards local file paths and never offers a rule")
    func localFilePrivacyBoundary() throws {
        let store = RoutingDecisionLogStore()
        let route = try request(
            url: "file:///Users/alice/Private/secret.html"
        )
        store.receive(route)
        store.updateResult(
            for: route.id,
            to: .opened(
                targetIdentifier: "opaque-file-target",
                targetDisplayLabel: "Example Browser"
            )
        )

        let entry = try #require(store.entries.first)
        let reflectedEntry = String(reflecting: entry)
        #expect(entry.destinationKind == .localFile)
        #expect(entry.webScheme == nil)
        #expect(entry.normalizedHost == nil)
        #expect(entry.destinationDisplayName == "Local File")
        #expect(entry.ruleCandidate == nil)
        #expect(!reflectedEntry.contains("/Users/alice"))
        #expect(!reflectedEntry.contains("secret.html"))
    }

    @Test("offers sanitized rule candidates only for successful web opens")
    func ruleEligibility() throws {
        for scheme in ["http", "https"] {
            let store = RoutingDecisionLogStore()
            let route = try request(
                url: "\(scheme)://Eligible.Example.COM/private/path?secret=yes#fragment"
            )
            store.receive(route)
            #expect(store.entries.first?.ruleCandidate == nil)

            store.updateResult(
                for: route.id,
                to: .opened(
                    targetIdentifier: "opaque:target:identifier",
                    targetDisplayLabel: "Work — Example Browser"
                )
            )

            let candidate = try #require(store.entries.first?.ruleCandidate)
            #expect(candidate.host == "eligible.example.com")
            #expect(candidate.targetIdentifier == "opaque:target:identifier")
            #expect(candidate.targetDisplayLabel == "Work — Example Browser")
            #expect(candidate.destination.scheme.rawValue == scheme)
            #expect(candidate.destination.url.host() == "eligible.example.com")
            #expect(candidate.destination.url.user() == nil)
            #expect(candidate.destination.url.password == nil)
            #expect(candidate.destination.url.port == nil)
            #expect(candidate.destination.url.path.isEmpty)
            #expect(candidate.destination.url.query() == nil)
            #expect(candidate.destination.url.fragment() == nil)
        }
    }

    @Test("provides stable source display names", arguments: [
        (RoutingRequest.Source.system, "System"),
        (RoutingRequest.Source.commandLine, "Command Line"),
        (RoutingRequest.Source.customURL, "Custom URL"),
        (RoutingRequest.Source.screenCapture, "Screen Capture"),
    ])
    func sourceDisplayNames(
        source: RoutingRequest.Source,
        expectedDisplayName: String
    ) throws {
        let entry = try RoutingDecisionLogEntry(
            request: request(
                url: "https://source.example",
                source: source
            ),
            receivedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(entry.sourceDisplayName == expectedDisplayName)
    }

    private func request(
        id: UUID = UUID(),
        url: String,
        source: RoutingRequest.Source = .system
    ) throws -> RoutingRequest {
        try RoutingRequest(
            id: id,
            destination: IncomingURL(url),
            source: source
        )
    }
}
