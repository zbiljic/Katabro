import Foundation

enum BrowserPickerLayout {
    static let width: CGFloat = 360
    static let minimumHeight: CGFloat = 216
    static let maximumHeight: CGFloat = 560
    static let baseHeight: CGFloat = 92
    static let rowHeight: CGFloat = 52
    static let rememberFooterHeight: CGFloat = 36

    static func height(
        browserCount: Int
    ) -> CGFloat {
        min(
            maximumHeight,
            max(
                minimumHeight,
                baseHeight + rememberFooterHeight + CGFloat(browserCount) * rowHeight
            )
        )
    }
}
