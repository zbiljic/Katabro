import AppKit
import KatabroCore

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
        let pasteboard = NSPasteboard.general
        let rawValue = pasteboard.string(forType: .URL)
            ?? pasteboard.string(forType: .string)

        return validatedURL(from: rawValue)
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
