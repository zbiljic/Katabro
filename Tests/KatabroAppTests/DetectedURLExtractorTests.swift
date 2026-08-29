@testable import Katabro
import KatabroCore
import Testing

@Suite("Detected URL extraction")
struct DetectedURLExtractorTests {
    @Test("preserves multiple links in visual recognition order")
    func multipleLinks() {
        #expect(urls(["https://one.example/a then http://two.example/b"]) == [
            "https://one.example/a", "http://two.example/b",
        ])
    }

    @Test("recognizes www links when NSDataDetector supports them")
    func wwwLinks() {
        let extracted = urls(["www.example.com/path"])
        #expect(extracted.isEmpty || extracted == ["http://www.example.com/path"])
    }

    @Test("excludes terminal punctuation")
    func punctuation() {
        #expect(urls(["Try https://example.com/path?q=a."]) == ["https://example.com/path?q=a"])
    }

    @Test("retains only the matched URL token from an OCR observation")
    func doesNotRetainSurroundingOCRText() {
        let extracted = DetectedURLExtractor.extract(from: [
            "Account 123-45-6789 password=private https://example.com/path?token=abc confidential note",
        ])
        #expect(extracted.count == 1)
        #expect(extracted[0].recognizedString == "https://example.com/path?token=abc")
        #expect(!extracted[0].recognizedString.contains("password"))
        #expect(!extracted[0].recognizedString.contains("confidential"))
    }

    @Test("removes exact duplicates while retaining case-distinct URLs and order")
    func duplicatesAndCase() {
        #expect(urls([
            "https://example.com/a https://EXAMPLE.com/a https://example.com/a",
        ]) == ["https://example.com/a", "https://EXAMPLE.com/a"])
    }

    @Test("rejects malformed and non-web schemes")
    func rejectedInputs() {
        #expect(urls([
            "plain words https:// incomplete.example file:///tmp/a mailto:me@example.com ftp://example.com data:text/plain,hello",
        ]).isEmpty)
    }

    private func urls(_ strings: [String]) -> [String] {
        DetectedURLExtractor.extract(from: strings).map(\.destination.url.absoluteString)
    }
}
