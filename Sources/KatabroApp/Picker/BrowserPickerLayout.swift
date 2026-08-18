import Foundation

struct BrowserPickerLayout: Equatable, Sendable {
    static let horizontalMinimumWidth: CGFloat = 196
    static let outerPadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 8
    static let rowSpacing: CGFloat = 4
    static let verticalRowHeight: CGFloat = 40
    static let verticalIconSize: CGFloat = 24
    static let horizontalCellWidth: CGFloat = 52
    static let horizontalCellSpacing: CGFloat = 8
    static let horizontalIconSize: CGFloat = 32
    static let destinationHeight: CGFloat = 16
    static let horizontalHintHeight: CGFloat = 16
    static let horizontalIconHeight: CGFloat = 32
    static let horizontalPerIconLabelHeight: CGFloat = 14
    static let horizontalSelectedLabelHeight: CGFloat = 16
    static let rememberFooterHeight: CGFloat = 29
    static let emptyContentHeight: CGFloat = 120

    let preferences: BrowserPickerPreferences
    let targetCount: Int
    let includesRememberFooter: Bool

    init(
        preferences: BrowserPickerPreferences = BrowserPickerPreferences(),
        targetCount: Int,
        includesRememberFooter: Bool
    ) {
        self.preferences = preferences
        self.targetCount = max(0, targetCount)
        self.includesRememberFooter = includesRememberFooter
    }

    var visibleTargetCount: Int {
        min(targetCount, preferences.visibleChoiceCount)
    }

    var showsDestination: Bool {
        preferences.destinationDisplay != .hidden
    }

    var width: CGFloat {
        switch preferences.orientation {
        case .vertical:
            return preferences.verticalWidth.points
        case .horizontal:
            let cellsWidth = CGFloat(visibleTargetCount) * Self.horizontalCellWidth
            let spacing = CGFloat(max(0, visibleTargetCount - 1)) * Self.horizontalCellSpacing
            return max(Self.horizontalMinimumWidth, cellsWidth + spacing + Self.outerPadding * 2)
        }
    }

    var collectionViewportWidth: CGFloat {
        width - Self.outerPadding * 2
    }

    var collectionViewportHeight: CGFloat {
        guard targetCount > 0 else { return 0 }
        switch preferences.orientation {
        case .vertical:
            return CGFloat(visibleTargetCount) * Self.verticalRowHeight
                + CGFloat(max(0, visibleTargetCount - 1)) * Self.rowSpacing
        case .horizontal:
            let hints = preferences.shortcutHintMode == .hidden ? 0 : Self.horizontalHintHeight
            let labels = preferences.horizontalLabelMode == .all ? Self.horizontalPerIconLabelHeight : 0
            return hints + Self.horizontalIconHeight + labels
        }
    }

    var height: CGFloat {
        var result = Self.outerPadding * 2
        if showsDestination {
            result += Self.destinationHeight
        }

        if targetCount == 0 {
            if showsDestination {
                result += Self.sectionSpacing
            }
            return result + Self.emptyContentHeight
        }

        if showsDestination {
            result += Self.sectionSpacing
        }
        result += collectionViewportHeight
        if preferences.orientation == .horizontal {
            result += Self.rowSpacing + Self.horizontalSelectedLabelHeight
        }
        if includesRememberFooter {
            result += Self.sectionSpacing + Self.rememberFooterHeight
        }
        return result
    }

    var overflows: Bool {
        targetCount > preferences.visibleChoiceCount
    }
}
