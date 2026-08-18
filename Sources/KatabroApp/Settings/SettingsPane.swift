import SwiftUI

enum SettingsPane: String, CaseIterable, Hashable {
    case general
    case browsers
    case picker
    case rules
    case about

    var displayName: LocalizedStringResource {
        switch self {
        case .general:
            "General"
        case .browsers:
            "Browsers"
        case .picker:
            "Picker"
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
        case .picker:
            "list.bullet.rectangle"
        case .rules:
            "arrow.triangle.branch"
        case .about:
            "info.circle"
        }
    }
}
