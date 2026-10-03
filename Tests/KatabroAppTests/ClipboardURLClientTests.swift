import AppKit
@testable import Katabro
import Testing

@Suite("Clipboard URL client")
struct ClipboardURLClientTests {
    struct AcceptedCase: Sendable {
        let rawValue: String
        let expectedAbsoluteString: String
    }

    @Test("reads web URLs from string representations", arguments: [
        "https://example.com/string",
        "[Documentation](<https://example.com/string>)",
        "The link is \"https://example.com/string\".\nOpen it here.",
    ])
    func readsStringRepresentation(rawValue: String) {
        withPasteboard { pasteboard in
            let item = NSPasteboardItem()
            item.setString(rawValue, forType: .string)
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
        AcceptedCase(
            rawValue: "[https://example.com/documentation/page.html]"
                + "(<https://example.com/documentation/page.html>)",
            expectedAbsoluteString: "https://example.com/documentation/page.html"
        ),
        AcceptedCase(
            rawValue: " \n[Documentation](https://example.com/path?query=value#fragment)\t ",
            expectedAbsoluteString: "https://example.com/path?query=value#fragment"
        ),
        AcceptedCase(
            rawValue: "[A **formatted** label](https://example.com/a_(b) \"Title\")",
            expectedAbsoluteString: "https://example.com/a_(b)"
        ),
        AcceptedCase(
            rawValue: "<https://example.com/path>",
            expectedAbsoluteString: "https://example.com/path"
        ),
        AcceptedCase(
            rawValue: "[Local document](file:///Users/example/document.html)",
            expectedAbsoluteString: "file:///Users/example/document.html"
        ),
        AcceptedCase(
            rawValue: "https://example.com/[label](path)",
            expectedAbsoluteString: "https://example.com/%5Blabel%5D(path)"
        ),
        AcceptedCase(
            rawValue: "example.com some prose",
            expectedAbsoluteString: "https://example.com"
        ),
        AcceptedCase(
            rawValue: "Visit example.com/path for details.",
            expectedAbsoluteString: "https://example.com/path"
        ),
        AcceptedCase(
            rawValue: "Open \"file:///Users/example/document.html\" please.",
            expectedAbsoluteString: "file:///Users/example/document.html"
        ),
        AcceptedCase(
            rawValue: "Read https://example.com/a_(b)?query=value#fragment.",
            expectedAbsoluteString: "https://example.com/a_(b)?query=value#fragment"
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

    @Test("extracts one destination from surrounding text", arguments: [
        "\"https://example.com/path\"",
        "'https://example.com/path'",
        "“https://example.com/path”",
        "‘https://example.com/path’",
        "(https://example.com/path)",
        "Here is https://example.com/path for you.",
        "https://example.com/path followed by more words",
        "The documentation:\nhttps://example.com/path\nThanks!",
        "https://example.com/path\nMore text",
        "See [Documentation](https://example.com/path) for details.",
        "\"[Documentation](<https://example.com/path>)\"",
        "See [https://other.example.com](https://example.com/path) for details.",
        "https://example.com/path and https://example.com/path",
        "[Docs](https://example.com/path) or https://example.com/path",
        "[Documentation](<https://example.com/path>",
        "`https://example.com/path`",
        "`[Code](https://example.com/path)`",
        "📚 Read https://example.com/path today.",
    ])
    func extractsURL(rawValue: String) {
        #expect(
            ClipboardURLClient.validatedURL(from: rawValue)?.absoluteString
                == "https://example.com/path"
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
        "https://example.com/path https://other.example.com/path",
        "https://example.com/path\nhttps://other.example.com/path",
        "Choose \"https://example.com\" or \"https://other.example.com\"",
        "See [Documentation](https://example.com) or https://other.example.com",
        "[One](https://example.com)[Two](https://other.example.com)",
        "[One](https://example.com)\n[Two](https://other.example.com)",
        "[Email](mailto:hello@example.com)",
        "[FTP](ftp://example.com/file)",
        "[Script](javascript:alert(1))",
        "[Remote file](file://remote.example.com/document.html)",
        "[Relative](docs/index.html)",
        "![Image](https://example.com/image.png)",
        "Email hello@example.com or open ftp://example.com/file",
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
