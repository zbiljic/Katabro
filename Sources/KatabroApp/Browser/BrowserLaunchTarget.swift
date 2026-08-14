import AppKit
import KatabroCore

struct BrowserLaunchTarget: Identifiable, Equatable {
    enum Kind: Equatable {
        case standard
        case privateWindow(BrowserPrivateMode)
        case profile(BrowserProfile)
    }

    let browser: BrowserApplication
    let kind: Kind

    var id: String {
        let browserIdentifier = browser.browser.bundleIdentifier.lowercased()

        switch kind {
        case .standard:
            return browserIdentifier
        case .privateWindow:
            return "\(browserIdentifier):private"
        case let .profile(profile):
            return "\(browserIdentifier):profile:\(profile.identifier)"
        }
    }

    var displayName: String {
        switch kind {
        case .standard:
            browser.browser.displayName
        case .privateWindow:
            "Private Window"
        case let .profile(profile):
            profile.displayName
        }
    }

    var detail: String? {
        switch kind {
        case .standard:
            nil
        case .privateWindow, .profile:
            browser.browser.displayName
        }
    }

    var accessibilityLabel: String {
        if let detail {
            return "Open in \(displayName), \(detail)"
        }

        return "Open in \(displayName)"
    }

    var icon: NSImage {
        browser.icon
    }

    var requiresUserScript: Bool {
        kind != .standard
    }

    func browserArguments(
        for destination: IncomingURL
    ) -> [String] {
        switch kind {
        case .standard:
            [destination.url.absoluteString]
        case let .privateWindow(mode):
            mode.arguments + [destination.url.absoluteString]
        case let .profile(profile):
            switch profile.family {
            case .chromium:
                [
                    "--profile-directory=\(profile.launchValue)",
                    destination.url.absoluteString,
                ]
            case .firefox:
                [
                    "-profile",
                    profile.launchValue,
                    "-no-remote",
                    destination.url.absoluteString,
                ]
            }
        }
    }
}
