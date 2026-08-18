import Foundation

enum BrowserPickerOrientation: String, Codable, CaseIterable, Sendable {
    case vertical
    case horizontal

    var displayName: String {
        switch self {
        case .vertical: "Vertical"
        case .horizontal: "Horizontal"
        }
    }
}

enum BrowserPickerVerticalWidth: String, Codable, CaseIterable, Sendable {
    case compact
    case standard

    var displayName: String {
        switch self {
        case .compact: "Compact (280 pt)"
        case .standard: "Standard (320 pt)"
        }
    }

    var points: CGFloat {
        switch self {
        case .compact: 280
        case .standard: 320
        }
    }
}

enum BrowserPickerDestinationDisplay: String, Codable, CaseIterable, Sendable {
    case domain
    case fullURL
    case hidden

    var displayName: String {
        switch self {
        case .domain: "Domain"
        case .fullURL: "Full URL"
        case .hidden: "Hidden"
        }
    }
}

enum BrowserPickerShortcutHintMode: String, Codable, CaseIterable, Sendable {
    case all
    case lettersOnly
    case numbersOnly
    case hidden

    var displayName: String {
        switch self {
        case .all: "All"
        case .lettersOnly: "Letters"
        case .numbersOnly: "Numbers"
        case .hidden: "Hidden"
        }
    }
}

enum BrowserPickerHorizontalLabelMode: String, Codable, CaseIterable, Sendable {
    case selectedOnly
    case all

    var displayName: String {
        switch self {
        case .selectedOnly: "Selected Only"
        case .all: "All"
        }
    }
}

struct BrowserPickerPreferences: Codable, Equatable, Sendable {
    static let visibleChoiceRange = 3 ... 8
    static let defaultVisibleChoiceCount = 5

    var orientation: BrowserPickerOrientation
    var verticalWidth: BrowserPickerVerticalWidth
    var visibleChoiceCount: Int {
        didSet { visibleChoiceCount = Self.clampedVisibleChoiceCount(visibleChoiceCount) }
    }

    var destinationDisplay: BrowserPickerDestinationDisplay
    var shortcutHintMode: BrowserPickerShortcutHintMode
    var horizontalLabelMode: BrowserPickerHorizontalLabelMode
    var showsRememberChoice: Bool

    init(
        orientation: BrowserPickerOrientation = .vertical,
        verticalWidth: BrowserPickerVerticalWidth = .standard,
        visibleChoiceCount: Int = defaultVisibleChoiceCount,
        destinationDisplay: BrowserPickerDestinationDisplay = .domain,
        shortcutHintMode: BrowserPickerShortcutHintMode = .all,
        horizontalLabelMode: BrowserPickerHorizontalLabelMode = .selectedOnly,
        showsRememberChoice: Bool = true
    ) {
        self.orientation = orientation
        self.verticalWidth = verticalWidth
        self.visibleChoiceCount = Self.clampedVisibleChoiceCount(visibleChoiceCount)
        self.destinationDisplay = destinationDisplay
        self.shortcutHintMode = shortcutHintMode
        self.horizontalLabelMode = horizontalLabelMode
        self.showsRememberChoice = showsRememberChoice
    }

    private enum CodingKeys: String, CodingKey {
        case orientation
        case verticalWidth
        case visibleChoiceCount
        case destinationDisplay
        case shortcutHintMode
        case horizontalLabelMode
        case showsRememberChoice
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orientation = (try? container.decode(BrowserPickerOrientation.self, forKey: .orientation)) ?? .vertical
        verticalWidth = (try? container.decode(BrowserPickerVerticalWidth.self, forKey: .verticalWidth)) ?? .standard
        visibleChoiceCount = Self.clampedVisibleChoiceCount(
            (try? container.decode(Int.self, forKey: .visibleChoiceCount)) ?? Self.defaultVisibleChoiceCount
        )
        destinationDisplay = (
            try? container.decode(BrowserPickerDestinationDisplay.self, forKey: .destinationDisplay)
        ) ??
            .domain
        shortcutHintMode = (try? container.decode(BrowserPickerShortcutHintMode.self, forKey: .shortcutHintMode)) ??
            .all
        horizontalLabelMode = (try? container.decode(
            BrowserPickerHorizontalLabelMode.self,
            forKey: .horizontalLabelMode
        )) ?? .selectedOnly
        showsRememberChoice = (try? container.decode(Bool.self, forKey: .showsRememberChoice)) ?? true
    }

    static func clampedVisibleChoiceCount(_ value: Int) -> Int {
        min(visibleChoiceRange.upperBound, max(visibleChoiceRange.lowerBound, value))
    }
}
