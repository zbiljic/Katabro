import Foundation
@testable import KatabroCore
import Testing

@Suite("Incoming URL validation")
struct IncomingURLTests {
    struct AcceptedCase: Sendable {
        let rawValue: String
        let scheme: IncomingURL.Scheme
        let host: String?
    }

    struct RejectedCase: Sendable {
        let rawValue: String
        let error: IncomingURL.ValidationError
    }

    @Test(
        "accepts absolute web URLs",
        arguments: [
            AcceptedCase(
                rawValue: "http://example.com",
                scheme: .http,
                host: "example.com"
            ),
            AcceptedCase(
                rawValue: "https://example.com/path?q=swift#results",
                scheme: .https,
                host: "example.com"
            ),
            AcceptedCase(
                rawValue: "  HTTPS://LOCALHOST:8443/path  ",
                scheme: .https,
                host: "localhost"
            ),
        ]
    )
    func acceptsWebURL(testCase: AcceptedCase) throws {
        let incomingURL = try IncomingURL(testCase.rawValue)

        #expect(incomingURL.scheme == testCase.scheme)
        #expect(incomingURL.url.host()?.lowercased() == testCase.host?.lowercased())
    }

    @Test(
        "accepts local absolute file URLs without rewriting",
        arguments: [
            AcceptedCase(rawValue: "file:///tmp/example.html", scheme: .file, host: nil),
            AcceptedCase(rawValue: "FILE:///tmp/example.html", scheme: .file, host: nil),
            AcceptedCase(rawValue: "file://LOCALHOST/tmp/example.html", scheme: .file, host: "localhost"),
            AcceptedCase(
                rawValue: "file:///tmp/example%20page.html?preview=true#section",
                scheme: .file,
                host: nil
            ),
        ]
    )
    func acceptsFileURL(testCase: AcceptedCase) throws {
        let incomingURL = try IncomingURL(testCase.rawValue)

        #expect(incomingURL.scheme == testCase.scheme)
        #expect(incomingURL.url.host()?.lowercased() == testCase.host?.lowercased())
        #expect(incomingURL.url.absoluteString == testCase.rawValue)
    }

    @Test(
        "rejects invalid destinations with stable errors",
        arguments: [
            RejectedCase(
                rawValue: "",
                error: .empty
            ),
            RejectedCase(
                rawValue: "docs/index.html",
                error: .relative
            ),
            RejectedCase(
                rawValue: "ftp://example.com/file",
                error: .unsupportedScheme("ftp")
            ),
            RejectedCase(
                rawValue: "https:///path",
                error: .missingHost
            ),
            RejectedCase(
                rawValue: "http://[invalid",
                error: .malformed
            ),
            RejectedCase(rawValue: "file:relative.html", error: .relative),
            RejectedCase(rawValue: "file:", error: .invalidFilePath),
            RejectedCase(rawValue: "file://", error: .invalidFilePath),
            RejectedCase(rawValue: "file:///", error: .invalidFilePath),
            RejectedCase(rawValue: "file:////server/share/page.html", error: .invalidFilePath),
            RejectedCase(
                rawValue: "file://server/share/page.html",
                error: .remoteFileAuthority("server")
            ),
            RejectedCase(
                rawValue: "file://user@localhost/page.html",
                error: .invalidFileAuthority
            ),
            RejectedCase(
                rawValue: "file://localhost:1234/page.html",
                error: .invalidFileAuthority
            ),
            RejectedCase(rawValue: "mailto:test@example.com", error: .unsupportedScheme("mailto")),
        ]
    )
    func rejectsInvalidURL(testCase: RejectedCase) {
        #expect(throws: testCase.error) {
            try IncomingURL(testCase.rawValue)
        }
    }

    @Test("normalizes schemes without rewriting the destination")
    func normalizesScheme() throws {
        let incomingURL = try IncomingURL("HTTP://Example.com/SomePath")

        #expect(incomingURL.scheme == .http)
        #expect(incomingURL.url.absoluteString == "HTTP://Example.com/SomePath")
    }

    @Test("rejects a relative URL that inherits an absolute base URL")
    func rejectsURLRelativeToBase() throws {
        let baseURL = try #require(URL(string: "https://example.com/root/"))
        let relativeURL = try #require(
            URL(
                string: "child",
                relativeTo: baseURL
            )
        )

        #expect(relativeURL.scheme == "https")
        #expect(relativeURL.host() == "example.com")
        #expect(throws: IncomingURL.ValidationError.relative) {
            try IncomingURL(relativeURL)
        }
    }

    @Test("provides a localized validation message")
    func providesLocalizedValidationMessage() {
        let error = IncomingURL.ValidationError.unsupportedScheme("ftp")

        #expect(
            error.localizedDescription ==
                "The URL scheme 'ftp' is not supported."
        )
    }
}
