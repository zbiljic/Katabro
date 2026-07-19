import Foundation
@testable import KatabroCore
import Testing

@Suite("Command-line requests")
struct CommandLineRequestTests {
    @Test(
        "requires exactly one argument",
        arguments: [
            [],
            ["https://one.example", "https://two.example"],
        ]
    )
    func requiresOneArgument(
        arguments: [String]
    ) {
        #expect(throws: CommandLineRequest.ParsingError.incorrectArgumentCount(arguments.count)) {
            try CommandLineRequest(
                arguments: arguments
            )
        }
    }

    @Test("rejects unsupported URLs with the core validation error")
    func rejectsInvalidURL() {
        #expect(
            throws: CommandLineRequest.ParsingError.invalidURL(
                .unsupportedScheme("file")
            )
        ) {
            try CommandLineRequest(
                arguments: ["file:///tmp/example"]
            )
        }
    }

    @Test("creates a transport envelope for a valid web URL")
    func createsTransportEnvelope() throws {
        let request = try CommandLineRequest(
            arguments: ["https://example.com/path?q=swift#result"]
        )

        let envelope = try request.transportURL()

        #expect(
            try KatabroURL.decode(envelope) == request.destination
        )
    }
}
