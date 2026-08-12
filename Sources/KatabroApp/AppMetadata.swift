import Foundation
import KatabroCore

enum AppMetadata {
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? KatabroCore.appBundleIdentifier
    }

    static let displayName = "Katabro"

    static var shortVersion: String {
        bundleValue(forInfoDictionaryKey: "CFBundleShortVersionString")
    }

    static var build: String {
        bundleValue(forInfoDictionaryKey: "CFBundleVersion")
    }

    static var versionDescription: String {
        "\(shortVersion) (\(build))"
    }

    static var copyright: String {
        bundleValue(forInfoDictionaryKey: "NSHumanReadableCopyright")
    }

    static let repositoryURL = aboutURL(
        "https://github.com/zbiljic/Katabro"
    )
    static let issuesURL = aboutURL(
        "https://github.com/zbiljic/Katabro/issues"
    )
    static let licenseURL = aboutURL(
        "https://github.com/zbiljic/Katabro/blob/main/LICENSE"
    )

    private static func bundleValue(
        forInfoDictionaryKey key: String
    ) -> String {
        guard
            let value = Bundle.main.object(
                forInfoDictionaryKey: key
            ) as? String,
            !value.isEmpty
        else {
            return "Unknown"
        }

        return value
    }

    private static func aboutURL(
        _ value: String
    ) -> URL {
        guard let url = URL(string: value) else {
            preconditionFailure(
                "Invalid static About URL: \(value)"
            )
        }

        return url
    }
}
