import AppKit
import KatabroCore

enum ClipboardURLReadError: LocalizedError {
    case noRoutableURL

    var errorDescription: String? {
        "The clipboard must contain an absolute HTTP, HTTPS, or local file URL that Katabro can open."
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
