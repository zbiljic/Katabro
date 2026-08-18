import Foundation
@testable import Katabro
import Testing

@Suite("Clipboard URL client")
struct ClipboardURLClientTests {
    @Test("accepts supported absolute URLs", arguments: [
        "https://example.com/path",
        " http://example.com \n",
        "file:///Users/example/document.html",
    ])
    func acceptsSupportedURL(
        rawValue: String
    ) {
        #expect(
            ClipboardURLClient.validatedURL(from: rawValue) != nil
        )
    }

    @Test("rejects text that cannot be routed", arguments: [
        nil,
        "",
        "example.com",
        "mailto:hello@example.com",
        "not a URL",
    ])
    func rejectsUnsupportedURL(
        rawValue: String?
    ) {
        #expect(
            ClipboardURLClient.validatedURL(from: rawValue) == nil
        )
    }
}
