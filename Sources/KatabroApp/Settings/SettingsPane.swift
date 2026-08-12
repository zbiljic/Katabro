import SwiftUI

enum SettingsPane: String, CaseIterable, Hashable {
    case general
    case browsers
    case about

    var displayName: LocalizedStringResource {
        switch self {
        case .general:
            "General"
        case .browsers:
            "Browsers"
        case .about:
            "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            "gear"
        case .browsers:
            "globe"
        case .about:
            "info.circle"
        }
    }
}
