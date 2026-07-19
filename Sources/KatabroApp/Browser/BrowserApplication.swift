import AppKit
import KatabroCore

struct BrowserApplication: Identifiable {
    var id: String {
        browser.id
    }

    let browser: Browser
    let applicationURL: URL
    let icon: NSImage
}

extension BrowserApplication: Equatable {
    static func == (
        lhs: BrowserApplication,
        rhs: BrowserApplication
    ) -> Bool {
        lhs.browser == rhs.browser &&
            lhs.applicationURL == rhs.applicationURL
    }
}
