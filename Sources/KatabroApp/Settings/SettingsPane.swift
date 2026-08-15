import SwiftUI

enum SettingsPane: String, CaseIterable, Hashable {
    case general
    case browsers
    case rules
    case about

    var displayName: LocalizedStringResource {
        switch self {
        case .general:
            "General"
        case .browsers:
            "Browsers"
        case .rules:
            "Rules"
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
        case .rules:
            "arrow.triangle.branch"
        case .about:
            "info.circle"
        }
    }
}
