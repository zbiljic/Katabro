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
    var availableSize: CGSize?

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

    var preferredWidth: CGFloat {
        switch preferences.orientation {
        case .vertical:
            return preferences.verticalWidth.points
        case .horizontal:
            let cellsWidth = CGFloat(visibleTargetCount) * Self.horizontalCellWidth
            let spacing = CGFloat(max(0, visibleTargetCount - 1)) * Self.horizontalCellSpacing
            return max(Self.horizontalMinimumWidth, cellsWidth + spacing + Self.outerPadding * 2)
        }
    }

    var width: CGFloat {
        min(preferredWidth, max(0, availableSize?.width ?? preferredWidth))
    }

    var contentWidth: CGFloat {
        max(min(Self.horizontalMinimumWidth, preferredWidth), width)
    }

    var collectionViewportWidth: CGFloat {
        contentWidth - Self.outerPadding * 2
    }

    var collectionViewportHeight: CGFloat {
        guard preferences.orientation == .vertical, targetCount > 0, let availableSize else {
            return preferredCollectionHeight
        }
        let chromeHeight = preferredHeight - preferredCollectionHeight
        return min(preferredCollectionHeight, max(Self.verticalRowHeight, availableSize.height - chromeHeight))
    }

    private var preferredCollectionHeight: CGFloat {
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
        min(contentHeight, max(0, availableSize?.height ?? contentHeight))
    }

    var contentHeight: CGFloat {
        preferredHeight - preferredCollectionHeight + collectionViewportHeight
    }

    private var preferredHeight: CGFloat {
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
        result += preferredCollectionHeight
        if preferences.orientation == .horizontal {
            result += Self.rowSpacing + Self.horizontalSelectedLabelHeight
        }
        if includesRememberFooter {
            result += Self.sectionSpacing + Self.rememberFooterHeight
        }
        return result
    }

    var requiresContentScrolling: Bool {
        contentWidth > width || contentHeight > height
    }

    func fitting(in size: CGSize) -> Self {
        var result = self
        result.availableSize = size
        return result
    }

    /// Give up the margin before reducing the requested content size.
    func availableFrame(in visibleFrame: CGRect) -> CGRect {
        visibleFrame.insetBy(
            dx: min(8, max(0, (visibleFrame.width - preferredWidth) / 2)),
            dy: min(8, max(0, (visibleFrame.height - preferredHeight) / 2))
        )
    }

    func frame(near pointer: CGPoint, in bounds: CGRect) -> CGRect {
        var proposedY = pointer.y - height - 12
        if proposedY < bounds.minY {
            proposedY = pointer.y + 12
        }
        return CGRect(
            x: min(max(pointer.x - width / 2, bounds.minX), bounds.maxX - width),
            y: min(max(proposedY, bounds.minY), bounds.maxY - height),
            width: width,
            height: height
        )
    }

    static func screenIndex(near pointer: CGPoint, frames: [CGRect], mainIndex: Int?) -> Int? {
        frames.firstIndex { $0.contains(pointer) }
            ?? mainIndex.flatMap { frames.indices.contains($0) ? $0 : nil }
            ?? frames.indices.first
    }

    var overflows: Bool {
        targetCount > preferences.visibleChoiceCount
    }
}
