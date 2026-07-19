import Foundation
@testable import Katabro
import Testing

@MainActor
@Suite("Default browser client")
struct DefaultBrowserClientTests {
    @Test("reports current only when both web schemes belong to Katabro")
    func refreshesStatus() {
        let state = DefaultBrowserState()
        state.handlers["http"] = "com.example.Katabro"
        state.handlers["https"] = "com.example.other"
        let client = DefaultBrowserClient(
            appBundleIdentifier: "com.example.Katabro",
            currentHandler: { scheme in
                state.handlers[scheme]
            },
            requestHandler: { _ in }
        )

        #expect(client.status == .notCurrent)

        state.handlers["https"] = "COM.EXAMPLE.KATABRO"
        client.refresh()

        #expect(client.status == .current)
    }

    @Test("requests both schemes and verifies the resulting handlers")
    func requestsDefaultBrowser() async {
        let state = DefaultBrowserState()
        state.handlers["http"] = "com.example.other"
        state.handlers["https"] = "com.example.other"
        let client = DefaultBrowserClient(
            appBundleIdentifier: "com.example.Katabro",
            currentHandler: { scheme in
                state.handlers[scheme]
            },
            requestHandler: { scheme in
                state.requestedSchemes.append(scheme)
                state.handlers[scheme] = "com.example.Katabro"
            }
        )

        await client.requestDefaultBrowser()

        #expect(state.requestedSchemes == ["http", "https"])
        #expect(client.status == .current)
        #expect(client.lastError == nil)
    }

    @Test("reports request failures without claiming success")
    func reportsRequestFailure() async {
        let client = DefaultBrowserClient(
            appBundleIdentifier: "com.example.Katabro",
            currentHandler: { _ in
                "com.example.other"
            },
            requestHandler: { _ in
                throw ClientTestError.expected
            }
        )

        await client.requestDefaultBrowser()

        #expect(client.status == .notCurrent)
        #expect(client.lastError == "expected")
    }
}

@MainActor
private final class DefaultBrowserState {
    var handlers: [String: String] = [:]
    var requestedSchemes: [String] = []
}

private enum ClientTestError: LocalizedError {
    case expected

    var errorDescription: String? {
        "expected"
    }
}
