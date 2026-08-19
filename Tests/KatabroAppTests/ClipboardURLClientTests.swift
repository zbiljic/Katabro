import AppKit
@testable import Katabro
import Testing

@Suite("Clipboard URL client")
struct ClipboardURLClientTests {
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
