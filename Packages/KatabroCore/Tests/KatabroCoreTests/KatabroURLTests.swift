import Foundation
@testable import KatabroCore
import Testing

@Suite("Katabro transport URLs")
struct KatabroURLTests {
    @Test("round-trips a destination containing query and fragment data")
    func roundTrip() throws {
        let destination = try IncomingURL(
            "https://example.com/search?q=swift&language=en#results"
        )

        let transportURL = try KatabroURL.encode(destination)
        let decodedDestination = try KatabroURL.decode(transportURL)

        #expect(transportURL.scheme == KatabroCore.transportScheme)
        #expect(transportURL.host() == "open")
        #expect(decodedDestination == destination)
    }

    @Test("round-trips a file destination without rewriting")
    func fileRoundTrip() throws {
        let destination = try IncomingURL(
            "file:///tmp/example%20page.html?preview=true#section"
        )

        let decodedDestination = try KatabroURL.decode(
            KatabroURL.encode(destination)
        )

        #expect(decodedDestination == destination)
        #expect(decodedDestination.url.absoluteString == destination.url.absoluteString)
    }

    @Test("rejects a non-Katabro scheme")
    func rejectsWrongScheme() throws {
        let url = try #require(URL(string: "https://example.com"))

        #expect(throws: KatabroURL.CodingError.wrongScheme("https")) {
            try KatabroURL.decode(url)
        }
    }

    @Test("rejects an unsupported transport action")
    func rejectsUnsupportedAction() throws {
        let url = try #require(URL(string: "katabro://settings"))

        #expect(throws: KatabroURL.CodingError.unsupportedAction("settings")) {
            try KatabroURL.decode(url)
        }
    }

    @Test(
        "rejects a missing destination",
        arguments: [
            "katabro://open",
            "katabro://open?url=",
            "katabro://open?other=https%3A%2F%2Fexample.com",
        ]
    )
    func rejectsMissingDestination(rawValue: String) throws {
        let url = try #require(URL(string: rawValue))

        #expect(throws: KatabroURL.CodingError.missingDestination) {
            try KatabroURL.decode(url)
        }
    }

    @Test("rejects duplicate destinations")
    func rejectsDuplicateDestinations() throws {
        let url = try #require(
            URL(
                string: "katabro://open?url=https%3A%2F%2Fone.example&url=https%3A%2F%2Ftwo.example"
            )
        )

        #expect(throws: KatabroURL.CodingError.duplicateDestination) {
            try KatabroURL.decode(url)
        }
    }

    @Test("rejects an unsupported destination scheme")
    func rejectsUnsupportedDestination() throws {
        let url = try #require(
            URL(
                string: "katabro://open?url=ftp%3A%2F%2Fexample.com%2Ffile"
            )
        )

        #expect(
            throws: KatabroURL.CodingError.invalidDestination(
                .unsupportedScheme("ftp")
            )
        ) {
            try KatabroURL.decode(url)
        }
    }

    @Test("provides a localized transport error message")
    func providesLocalizedTransportErrorMessage() {
        let error = KatabroURL.CodingError.missingDestination

        #expect(
            error.localizedDescription ==
                "The Katabro URL is missing its destination."
        )
    }
}
