import AppKit
import KatabroCore
import Network

enum ClipboardURLReadError: LocalizedError {
    case noRoutableURL

    var errorDescription: String? {
        "The clipboard must contain an absolute HTTP, HTTPS, or local file URL, "
            + "or an unambiguous domain-like web address that Katabro can open."
    }
}

enum ClipboardURLWriteError: LocalizedError {
    case couldNotWrite

    var errorDescription: String? {
        "Katabro could not copy the link to the clipboard."
    }
}

@MainActor
struct ClipboardURLClient {
    typealias CurrentURLHandler = @MainActor () -> URL?
    typealias ChangeCountHandler = @MainActor () -> Int
    typealias CopyURLHandler = @MainActor (URL) throws -> Void

    private let currentURLHandler: CurrentURLHandler
    private let changeCountHandler: ChangeCountHandler
    private let copyURLHandler: CopyURLHandler

    init(
        currentURLHandler: @escaping CurrentURLHandler,
        changeCountHandler: @escaping ChangeCountHandler = { 0 },
        copyURLHandler: @escaping CopyURLHandler = { _ in }
    ) {
        self.currentURLHandler = currentURLHandler
        self.changeCountHandler = changeCountHandler
        self.copyURLHandler = copyURLHandler
    }

    static let live = Self(
        currentURLHandler: {
            currentURL(in: NSPasteboard.general)
        },
        changeCountHandler: {
            NSPasteboard.general.changeCount
        },
        copyURLHandler: { url in
            try copy(url, to: NSPasteboard.general)
        }
    )

    func currentURL() -> URL? {
        currentURLHandler()
    }

    func changeCount() -> Int {
        changeCountHandler()
    }

    func copy(
        _ url: URL
    ) throws {
        try copyURLHandler(url)
    }

    static func validatedURL(
        from rawValue: String?
    ) -> URL? {
        guard let rawValue else {
            return nil
        }

        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedValue.contains(where: \.isWhitespace) {
            if let url = (try? IncomingURL(trimmedValue))?.url ?? inferredHTTPSURL(from: trimmedValue) {
                return url
            }
        }

        return extractedURL(from: trimmedValue)
    }

    private static func extractedURL(
        from value: String
    ) -> URL? {
        guard
            let markdown = try? AttributedString(
                markdown: value,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ),
            let detector = try? NSDataDetector(
                types: NSTextCheckingResult.CheckingType.link.rawValue
            )
        else {
            return nil
        }

        var destinations = Set<URL>()
        for run in markdown.runs {
            if let link = run.link {
                var value = link.absoluteString
                let prefix = markdown.characters[..<run.range.lowerBound].last
                let suffix = markdown.characters[run.range].last
                // Markdown autolinks can include a smart closing quote in the destination.
                let doubleQuote = prefix == "“" && suffix == "”" && value.hasSuffix("%E2%80%9D")
                let singleQuote = prefix == "‘" && suffix == "’" && value.hasSuffix("%E2%80%99")
                if doubleQuote || singleQuote {
                    value.removeLast(9)
                }
                guard let destination = try? IncomingURL(value) else {
                    return nil
                }
                destinations.insert(destination.url)
                continue
            }

            let text = String(markdown[run.range].characters)
            for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard
                    let range = Range(match.range, in: text),
                    // Do not salvage a hostname from an invalid token such as -example.com.
                    range.lowerBound == text.startIndex
                    || text[text.index(before: range.lowerBound)].isWhitespace
                    || "([{<\"'“‘`".contains(text[text.index(before: range.lowerBound)])
                else {
                    continue
                }

                var token = String(text[range])
                let prefix = text[..<range.lowerBound].last
                // NSDataDetector includes smart closing quotes in the matched path.
                if (prefix == "“" && token.last == "”") || (prefix == "‘" && token.last == "’") {
                    token.removeLast()
                }
                if let destination = (try? IncomingURL(token))?.url ?? inferredHTTPSURL(from: token) {
                    destinations.insert(destination)
                }
            }
        }

        return destinations.count == 1 ? destinations.first : nil
    }

    private static func inferredHTTPSURL(
        from value: String
    ) -> URL? {
        guard
            !value.isEmpty,
            !declaresExplicitScheme(value),
            let incomingURL = try? IncomingURL("https://\(value)"),
            let components = URLComponents(
                url: incomingURL.url,
                resolvingAgainstBaseURL: false
            ),
            components.user == nil,
            components.password == nil,
            let host = incomingURL.url.host(),
            isValidInferredHost(host)
        else {
            return nil
        }

        return incomingURL.url
    }

    private static func declaresExplicitScheme(
        _ value: String
    ) -> Bool {
        guard URLComponents(string: value)?.scheme != nil else {
            return false
        }

        return !hasDomainOrIPv4PortPrefix(value)
    }

    private static func hasDomainOrIPv4PortPrefix(
        _ value: String
    ) -> Bool {
        let authority = value.prefix { character in
            character != "/" && character != "?" && character != "#"
        }

        guard
            let separator = authority.lastIndex(of: ":"),
            separator != authority.startIndex
        else {
            return false
        }

        let host = String(authority[..<separator])
        let port = authority[authority.index(after: separator)...]
        guard
            !port.isEmpty,
            port.utf8.allSatisfy({ (48 ... 57).contains($0) }),
            let portNumber = Int(port),
            (0 ... 65535).contains(portNumber)
        else {
            return false
        }

        return isIPv4Literal(host) || isDNSHostname(host)
    }

    private static func isValidInferredHost(
        _ host: String
    ) -> Bool {
        isIPv6Literal(host)
            || isIPv4Literal(host)
            || isDNSHostname(host)
    }

    private static func isIPv6Literal(
        _ host: String
    ) -> Bool {
        IPv6Address(host) != nil
    }

    private static func isIPv4Literal(
        _ host: String
    ) -> Bool {
        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else {
            return false
        }

        return octets.allSatisfy { octet in
            !octet.isEmpty
                && octet.utf8.allSatisfy { (48 ... 57).contains($0) }
                && Int(octet).map { (0 ... 255).contains($0) } == true
        }
    }

    private static func isDNSHostname(
        _ host: String
    ) -> Bool {
        let hostname = host.hasSuffix(".") ? String(host.dropLast()) : host
        let labels = hostname.split(separator: ".", omittingEmptySubsequences: false)

        guard
            labels.count >= 2,
            labels.allSatisfy(isDNSLabel),
            let finalLabel = labels.last,
            finalLabel.utf8.contains(where: isASCIILetter)
        else {
            return false
        }

        return true
    }

    private static func isDNSLabel(
        _ label: Substring
    ) -> Bool {
        let bytes = Array(label.utf8)
        guard
            (1 ... 63).contains(bytes.count),
            let first = bytes.first,
            let last = bytes.last,
            isASCIIAlphanumeric(first),
            isASCIIAlphanumeric(last)
        else {
            return false
        }

        return bytes.allSatisfy { byte in
            isASCIIAlphanumeric(byte) || byte == 45
        }
    }

    private static func isASCIIAlphanumeric(
        _ byte: UInt8
    ) -> Bool {
        isASCIILetter(byte) || (48 ... 57).contains(byte)
    }

    private static func isASCIILetter(
        _ byte: UInt8
    ) -> Bool {
        (65 ... 90).contains(byte) || (97 ... 122).contains(byte)
    }

    static func currentURL(
        in pasteboard: NSPasteboard
    ) -> URL? {
        guard let item = pasteboard.pasteboardItems?.first else {
            return nil
        }

        for type in [NSPasteboard.PasteboardType.URL, .fileURL, .string] {
            if let url = validatedURL(from: item.string(forType: type)) {
                return url
            }
        }

        return nil
    }

    static func copy(
        _ url: URL,
        to pasteboard: NSPasteboard
    ) throws {
        pasteboard.prepareForNewContents()

        let item = NSPasteboardItem()
        let canonicalType: NSPasteboard.PasteboardType = url.isFileURL ? .fileURL : .URL
        item.setString(url.absoluteString, forType: canonicalType)
        item.setString(url.absoluteString, forType: .string)

        guard pasteboard.writeObjects([item]) else {
            throw ClipboardURLWriteError.couldNotWrite
        }
    }

    #if DEBUG
        static func development(
            url: URL?,
            copyURLHandler: @escaping CopyURLHandler = { _ in }
        ) -> Self {
            Self(
                currentURLHandler: { url },
                copyURLHandler: copyURLHandler
            )
        }
    #endif
}
