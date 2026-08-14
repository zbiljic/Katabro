import Foundation

enum BrowserFamily: String, Codable, Equatable, Sendable {
    case chromium
    case firefox
}

enum BrowserPrivateMode: Equatable, Sendable {
    case chromium
    case firefox
    case opera

    var arguments: [String] {
        switch self {
        case .chromium:
            ["--incognito"]
        case .firefox:
            ["--private-window"]
        case .opera:
            ["--private"]
        }
    }
}

struct BrowserProfile: Codable, Equatable, Identifiable, Sendable {
    let identifier: String
    let displayName: String
    let launchValue: String
    let family: BrowserFamily

    var id: String {
        identifier
    }
}

struct BrowserProfileSupport: Equatable, Sendable {
    let family: BrowserFamily
    let privateMode: BrowserPrivateMode
    let suggestedDirectory: String

    static func support(
        for bundleIdentifier: String
    ) -> Self? {
        supportedBrowsers[bundleIdentifier.lowercased()]
    }

    private static let supportedBrowsers: [String: Self] = [
        // Google Chrome and Chromium channels.
        "com.google.chrome": chromium("Google/Chrome"),
        "com.google.chrome.beta": chromium("Google/Chrome Beta"),
        "com.google.chrome.dev": chromium("Google/Chrome Dev"),
        "com.google.chrome.canary": chromium("Google/Chrome Canary"),
        "org.chromium.chromium": chromium("Chromium"),

        // Brave channels.
        "com.brave.browser": chromium("BraveSoftware/Brave-Browser"),
        "com.brave.browser.beta": chromium("BraveSoftware/Brave-Browser-Beta"),
        "com.brave.browser.dev": chromium("BraveSoftware/Brave-Browser-Dev"),
        "com.brave.browser.nightly": chromium("BraveSoftware/Brave-Browser-Nightly"),

        // Microsoft Edge channels.
        "com.microsoft.edgemac": chromium("Microsoft Edge"),
        "com.microsoft.edgemac.beta": chromium("Microsoft Edge Beta"),
        "com.microsoft.edgemac.dev": chromium("Microsoft Edge Dev"),
        "com.microsoft.edgemac.canary": chromium("Microsoft Edge Canary"),

        // Other Chromium-family browsers with Chromium-compatible profile stores.
        "com.vivaldi.vivaldi": chromium("Vivaldi"),
        "com.vivaldi.vivaldi.snapshot": chromium("Vivaldi Snapshot"),
        "net.imput.helium": chromium("net.imput.helium"),
        "company.thebrowser.browser": chromium("Arc/User Data"),
        "company.thebrowser.browser.beta": chromium("Arc Beta/User Data"),
        "company.thebrowser.browser.canary": chromium("Arc Canary/User Data"),
        "company.thebrowser.dia": chromium("Dia/User Data"),
        "ai.perplexity.comet": chromium("Comet"),
        "com.bookry.wavebox": chromium("WaveboxApp"),
        "ru.yandex.desktop.yandex-browser": chromium("Yandex/YandexBrowser"),
        "com.operasoftware.opera": chromium(
            "com.operasoftware.Opera",
            privateMode: .opera
        ),
        "com.operasoftware.operagx": chromium(
            "com.operasoftware.OperaGX",
            privateMode: .opera
        ),

        // Mozilla Firefox channels and Firefox-family browsers.
        "org.mozilla.firefox": firefox("Firefox"),
        "org.mozilla.firefoxdeveloperedition": firefox("Firefox"),
        "org.mozilla.nightly": firefox("Firefox"),
        "app.zen-browser.zen": firefox("zen"),
        "app.glide-browser.glide": firefox("glide"),
        "io.gitlab.librewolf-community": firefox("librewolf"),
        "one.ablaze.floorp": firefox("Floorp"),
        "net.waterfox.waterfox": firefox("Waterfox"),
    ]

    private static func chromium(
        _ relativeDirectory: String,
        privateMode: BrowserPrivateMode = .chromium
    ) -> Self {
        Self(
            family: .chromium,
            privateMode: privateMode,
            suggestedDirectory: applicationSupport(relativeDirectory)
        )
    }

    private static func firefox(
        _ relativeDirectory: String
    ) -> Self {
        Self(
            family: .firefox,
            privateMode: .firefox,
            suggestedDirectory: applicationSupport(relativeDirectory)
        )
    }

    private static func applicationSupport(
        _ relativeDirectory: String
    ) -> String {
        "~/Library/Application Support/\(relativeDirectory)"
    }
}
