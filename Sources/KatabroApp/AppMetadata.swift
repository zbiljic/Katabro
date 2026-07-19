import Foundation
import KatabroCore

enum AppMetadata {
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? KatabroCore.appBundleIdentifier
    }

    static let displayName = "Katabro"
}
