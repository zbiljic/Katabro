import AppKit
import KatabroCore

enum ClipboardURLReadError: LocalizedError {
    case noRoutableURL

    var errorDescription: String? {
        "The clipboard must contain an absolute HTTP, HTTPS, or local file URL that Katabro can open."
    }
}

@MainActor
struct ClipboardURLClient {
    typealias CurrentURLHandler = @MainActor () -> URL?

    private let currentURLHandler: CurrentURLHandler

    init(
        currentURLHandler: @escaping CurrentURLHandler
    ) {
        self.currentURLHandler = currentURLHandler
    }

    static let live = Self {
        currentURL(in: NSPasteboard.general)
    }

    func currentURL() -> URL? {
        currentURLHandler()
    }

    static func validatedURL(
        from rawValue: String?
    ) -> URL? {
        guard
            let rawValue,
            let incomingURL = try? IncomingURL(rawValue)
        else {
            return nil
        }

        return incomingURL.url
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

    #if DEBUG
        static func development(
            url: URL?
        ) -> Self {
            Self {
                url
            }
        }
    #endif
}
