import AppKit
@testable import Katabro
import Testing

@Suite("Clipboard URL client")
struct ClipboardURLClientTests {
    struct AcceptedCase: Sendable {
        let rawValue: String
        let expectedAbsoluteString: String
    }

    @Test("reads web URLs from string representations")
    func readsStringRepresentation() {
        withPasteboard { pasteboard in
            let item = NSPasteboardItem()
            item.setString("https://example.com/string", forType: .string)
            #expect(pasteboard.writeObjects([item]))

            #expect(
                ClipboardURLClient.currentURL(in: pasteboard)
                    == URL(string: "https://example.com/string")
            )
        }
    }

    @Test("infers HTTPS for a domain-like string representation")
    func infersHTTPSFromStringRepresentation() {
        withPasteboard { pasteboard in
            let item = NSPasteboardItem()
            item.setString("github.com/github/gh", forType: .string)
            #expect(pasteboard.writeObjects([item]))

            #expect(
                ClipboardURLClient.currentURL(in: pasteboard)
                    == URL(string: "https://github.com/github/gh")
            )
        }
    }

    @Test("reads web URLs from URL representations")
    func readsURLRepresentation() {
        withPasteboard { pasteboard in
            let item = NSPasteboardItem()
            item.setString("https://example.com/url", forType: .URL)
            #expect(pasteboard.writeObjects([item]))

            #expect(
                ClipboardURLClient.currentURL(in: pasteboard)
                    == URL(string: "https://example.com/url")
            )
        }
    }

    @Test("reads local URLs from file URL representations")
    func readsFileURLRepresentation() {
        withPasteboard { pasteboard in
            let item = NSPasteboardItem()
            item.setString("file:///Users/example/document.html", forType: .fileURL)
            #expect(pasteboard.writeObjects([item]))

            #expect(
                ClipboardURLClient.currentURL(in: pasteboard)
                    == URL(string: "file:///Users/example/document.html")
            )
        }
    }

    @Test("continues past an invalid preferred representation")
    func fallsBackFromInvalidURLRepresentation() {
        withPasteboard { pasteboard in
            let item = NSPasteboardItem()
            item.setString("not-a-url", forType: .URL)
            item.setString("https://example.com/fallback", forType: .string)
            #expect(pasteboard.writeObjects([item]))

            #expect(
                ClipboardURLClient.currentURL(in: pasteboard)
                    == URL(string: "https://example.com/fallback")
            )
        }
    }

    @Test("returns nil when the first item has no supported URL")
    func rejectsUnsupportedFirstItem() {
        withPasteboard { pasteboard in
            let item = NSPasteboardItem()
            item.setString("not-a-url", forType: .string)
            #expect(pasteboard.writeObjects([item]))

            #expect(ClipboardURLClient.currentURL(in: pasteboard) == nil)
        }
    }

    @Test("reads only the first pasteboard item")
    func ignoresLaterItems() {
        withPasteboard { pasteboard in
            let first = NSPasteboardItem()
            first.setString("not-a-url", forType: .string)
            let second = NSPasteboardItem()
            second.setString("https://example.com/second", forType: .string)
            #expect(pasteboard.writeObjects([first, second]))

            #expect(ClipboardURLClient.currentURL(in: pasteboard) == nil)
        }
    }

    @Test("writes web URLs as URL and string representations")
    func writesWebURLRepresentations() throws {
        try withPasteboard { pasteboard in
            let url = try #require(
                URL(string: "https://example.com/path?query=value#fragment")
            )

            try ClipboardURLClient.copy(url, to: pasteboard)

            let item = try #require(pasteboard.pasteboardItems?.first)
            #expect(item.types == [.URL, .string])
            #expect(item.string(forType: .URL) == url.absoluteString)
            #expect(item.string(forType: .string) == url.absoluteString)
            #expect(item.string(forType: .fileURL) == nil)
        }
    }

    @Test("writes local URLs as file URL and string representations")
    func writesFileURLRepresentations() throws {
        try withPasteboard { pasteboard in
            let url = URL(fileURLWithPath: "/Users/example/document.html")

            try ClipboardURLClient.copy(url, to: pasteboard)

            let item = try #require(pasteboard.pasteboardItems?.first)
            #expect(item.types == [.fileURL, .string])
            #expect(item.string(forType: .fileURL) == url.absoluteString)
            #expect(item.string(forType: .string) == url.absoluteString)
            #expect(item.string(forType: .URL) == nil)
        }
    }

    @Test("accepts supported clipboard URLs", arguments: [
        AcceptedCase(
            rawValue: "github.com/github/gh",
            expectedAbsoluteString: "https://github.com/github/gh"
        ),
        AcceptedCase(
            rawValue: " \nMiXeD.Example.COM:8443/Some/Path?Query=Value#Fragment\t ",
            expectedAbsoluteString: "https://MiXeD.Example.COM:8443/Some/Path?Query=Value#Fragment"
        ),
        AcceptedCase(
            rawValue: "127.0.0.1:8443/path",
            expectedAbsoluteString: "https://127.0.0.1:8443/path"
        ),
        AcceptedCase(
            rawValue: "[2001:db8::1]/path",
            expectedAbsoluteString: "https://[2001:db8::1]/path"
        ),
        AcceptedCase(
            rawValue: "example.xn--p1ai/path",
            expectedAbsoluteString: "https://example.xn--p1ai/path"
        ),
        AcceptedCase(
            rawValue: "example.com./path",
            expectedAbsoluteString: "https://example.com./path"
        ),
        AcceptedCase(
            rawValue: "http://example.com/path",
            expectedAbsoluteString: "http://example.com/path"
        ),
        AcceptedCase(
            rawValue: " https://example.com/path \n",
            expectedAbsoluteString: "https://example.com/path"
        ),
        AcceptedCase(
            rawValue: "file:///Users/example/document.html",
            expectedAbsoluteString: "file:///Users/example/document.html"
        ),
    ])
    func acceptsSupportedURL(
        testCase: AcceptedCase
    ) {
        #expect(
            ClipboardURLClient.validatedURL(from: testCase.rawValue)?.absoluteString
                == testCase.expectedAbsoluteString
        )
    }

    @Test("rejects text that cannot be routed", arguments: [
        nil,
        "",
        " \n\t ",
        "not-a-url",
        "docs/index.html",
        "localhost:3000/path",
        "intranet/path",
        "mailto:hello@example.com",
        "ftp://example.com/file",
        "user@example.com/path",
        "example..com",
        "-example.com",
        "example_com/path",
        "example.123/path",
        "256.1.1.1/path",
        "[gggg::1]/path",
        "[hello]/path",
        "example.com some prose",
    ])
    func rejectsUnsupportedURL(
        rawValue: String?
    ) {
        #expect(
            ClipboardURLClient.validatedURL(from: rawValue) == nil
        )
    }

    private func withPasteboard(
        _ operation: (NSPasteboard) throws -> Void
    ) rethrows {
        let pasteboard = NSPasteboard.withUniqueName()
        defer {
            pasteboard.clearContents()
            pasteboard.releaseGlobally()
        }

        pasteboard.clearContents()
        try operation(pasteboard)
    }
}
