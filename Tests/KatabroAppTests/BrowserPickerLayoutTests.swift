import CoreGraphics
@testable import Katabro
import Testing

@Suite("Browser picker layout")
struct BrowserPickerLayoutTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let count: Int
        let verticalHeight: Double
        let horizontalWidth: Double

        var testDescription: String {
            "count \(count)"
        }
    }

    struct VerticalWidthCase: Sendable, CustomTestStringConvertible {
        let width: BrowserPickerVerticalWidth
        let count: Int
        let visibleChoices: Int
        let destination: BrowserPickerDestinationDisplay
        let includesRememberFooter: Bool
        let expected: Double

        var testDescription: String {
            "\(width.rawValue), count \(count), \(visibleChoices) visible choices"
        }
    }

    @Test(
        "default dimensions are compact and capped",
        arguments: [
            Case(count: 0, verticalHeight: 168, horizontalWidth: 196),
            Case(count: 1, verticalHeight: 125, horizontalWidth: 196),
            Case(count: 4, verticalHeight: 257, horizontalWidth: 256),
            Case(count: 5, verticalHeight: 301, horizontalWidth: 316),
            Case(count: 12, verticalHeight: 301, horizontalWidth: 316),
        ]
    )
    func defaultDimensions(testCase: Case) {
        let vertical = BrowserPickerLayout(
            targetCount: testCase.count,
            includesRememberFooter: testCase.count >= 1
        )
        var horizontalPreferences = BrowserPickerPreferences()
        horizontalPreferences.orientation = .horizontal
        let horizontal = BrowserPickerLayout(
            preferences: horizontalPreferences,
            targetCount: testCase.count,
            includesRememberFooter: testCase.count >= 1
        )

        #expect(Double(vertical.height) == testCase.verticalHeight)
        #expect(Double(horizontal.width) == testCase.horizontalWidth)
        #expect(Double(horizontal.height) == (testCase.count < 1 ? 168 : 153))
    }

    @Test("negative target counts use the empty layout")
    func negativeCount() {
        let layout = BrowserPickerLayout(targetCount: -5, includesRememberFooter: true)
        #expect(layout.targetCount == 0)
        #expect(layout.height == 168)
        #expect(!layout.overflows)
    }

    @Test("conditional chrome contributes explicit metrics")
    func conditionalMetrics() {
        let withFooter = BrowserPickerLayout(targetCount: 4, includesRememberFooter: true)
        let withoutFooter = BrowserPickerLayout(targetCount: 4, includesRememberFooter: false)
        #expect(abs(
            withFooter.height
                - (withoutFooter.height + BrowserPickerLayout.sectionSpacing + BrowserPickerLayout.rememberFooterHeight)
        ) < 0.001)

        var preferences = BrowserPickerPreferences()
        preferences.destinationDisplay = .hidden
        let hiddenDestination = BrowserPickerLayout(
            preferences: preferences,
            targetCount: 4,
            includesRememberFooter: true
        )
        #expect(abs(
            withFooter.height
                -
                (hiddenDestination.height + BrowserPickerLayout.destinationHeight + BrowserPickerLayout
                    .sectionSpacing)
        ) < 0.001)
    }

    @Test("visible choice count clamps and controls both axes")
    func choiceCountClamps() {
        #expect(BrowserPickerPreferences(visibleChoiceCount: 1).visibleChoiceCount == 3)
        #expect(BrowserPickerPreferences(visibleChoiceCount: 20).visibleChoiceCount == 8)

        let vertical = BrowserPickerLayout(
            preferences: BrowserPickerPreferences(visibleChoiceCount: 3),
            targetCount: 12,
            includesRememberFooter: true
        )
        let horizontal = BrowserPickerLayout(
            preferences: BrowserPickerPreferences(orientation: .horizontal, visibleChoiceCount: 8),
            targetCount: 12,
            includesRememberFooter: true
        )
        #expect(vertical.visibleTargetCount == 3)
        #expect(horizontal.width == 496)
    }

    @Test(
        "horizontal configured counts expose exact cells without a partial next cell",
        arguments: [
            (count: 3, width: 196.0),
            (count: 4, width: 256.0),
            (count: 5, width: 316.0),
        ]
    )
    func exactHorizontalChoiceWidths(testCase: (count: Int, width: Double)) {
        let layout = BrowserPickerLayout(
            preferences: BrowserPickerPreferences(
                orientation: .horizontal,
                visibleChoiceCount: testCase.count
            ),
            targetCount: 12,
            includesRememberFooter: true
        )

        #expect(Double(layout.width) == testCase.width)
        #expect(
            Double(layout.collectionViewportWidth)
                == testCase.width - Double(BrowserPickerLayout.outerPadding * 2)
        )
    }

    @Test(
        "vertical widths are exact and independent of other layout inputs",
        arguments: [
            VerticalWidthCase(
                width: BrowserPickerVerticalWidth.compact,
                count: 0,
                visibleChoices: 3,
                destination: BrowserPickerDestinationDisplay.hidden,
                includesRememberFooter: false,
                expected: 280.0
            ),
            VerticalWidthCase(
                width: BrowserPickerVerticalWidth.compact,
                count: 12,
                visibleChoices: 8,
                destination: BrowserPickerDestinationDisplay.fullURL,
                includesRememberFooter: true,
                expected: 280.0
            ),
            VerticalWidthCase(
                width: BrowserPickerVerticalWidth.standard,
                count: 1,
                visibleChoices: 3,
                destination: BrowserPickerDestinationDisplay.hidden,
                includesRememberFooter: false,
                expected: 320.0
            ),
            VerticalWidthCase(
                width: BrowserPickerVerticalWidth.standard,
                count: 12,
                visibleChoices: 8,
                destination: BrowserPickerDestinationDisplay.fullURL,
                includesRememberFooter: true,
                expected: 320.0
            ),
        ]
    )
    func exactVerticalWidths(testCase: VerticalWidthCase) {
        let layout = BrowserPickerLayout(
            preferences: BrowserPickerPreferences(
                orientation: .vertical,
                verticalWidth: testCase.width,
                visibleChoiceCount: testCase.visibleChoices,
                destinationDisplay: testCase.destination
            ),
            targetCount: testCase.count,
            includesRememberFooter: testCase.includesRememberFooter
        )

        #expect(Double(layout.width) == testCase.expected)
    }

    @Test("vertical width does not alter horizontal width")
    func verticalWidthDoesNotAffectHorizontalLayout() {
        let compact = BrowserPickerLayout(
            preferences: BrowserPickerPreferences(
                orientation: .horizontal,
                verticalWidth: .compact,
                visibleChoiceCount: 5
            ),
            targetCount: 12,
            includesRememberFooter: true
        )
        let standard = BrowserPickerLayout(
            preferences: BrowserPickerPreferences(
                orientation: .horizontal,
                verticalWidth: .standard,
                visibleChoiceCount: 5
            ),
            targetCount: 12,
            includesRememberFooter: true
        )

        #expect(compact.width == 316)
        #expect(standard.width == 316)
    }
}

@Suite("Browser picker hover selection arbitration")
struct BrowserPickerHoverArbitratorTests {
    @Test("stationary pointer cannot overwrite keyboard selection")
    func stationaryPointerIsSuppressed() {
        let pointerPosition = CGPoint(x: 240, y: 160)
        var arbitrator = BrowserPickerHoverSelectionArbitrator()

        arbitrator.keyboardNavigationOccurred(at: pointerPosition)
        let shouldSelect = arbitrator.shouldSelectForHover(at: pointerPosition)

        #expect(!shouldSelect)
        #expect(arbitrator.keyboardPointerPosition == pointerPosition)
    }

    @Test("moving the pointer immediately restores hover selection")
    func pointerMovementRestoresHover() {
        let keyboardPosition = CGPoint(x: 240, y: 160)
        let movedPosition = CGPoint(x: 241, y: 160)
        var arbitrator = BrowserPickerHoverSelectionArbitrator()
        arbitrator.keyboardNavigationOccurred(at: keyboardPosition)
        let shouldSelectAfterMoving = arbitrator.shouldSelectForHover(at: movedPosition)
        let shouldKeepSelecting = arbitrator.shouldSelectForHover(at: movedPosition)

        #expect(shouldSelectAfterMoving)
        #expect(arbitrator.keyboardPointerPosition == nil)
        #expect(shouldKeepSelecting)
    }
}

@Suite("Browser picker selection scrolling")
struct BrowserPickerSelectionScrollPolicyTests {
    @Test("keyboard selection scrolls exactly once")
    func keyboardSelectionScrolls() {
        var policy = BrowserPickerSelectionScrollPolicy()

        policy.keyboardNavigationOccurred()
        let shouldScroll = policy.consumePendingKeyboardScroll()
        let shouldScrollAgain = policy.consumePendingKeyboardScroll()

        #expect(shouldScroll)
        #expect(!shouldScrollAgain)
    }

    @Test("hover selection clears pending keyboard scrolling")
    func hoverSelectionDoesNotScroll() {
        var policy = BrowserPickerSelectionScrollPolicy()

        policy.keyboardNavigationOccurred()
        policy.hoverSelectionOccurred()
        let shouldScroll = policy.consumePendingKeyboardScroll()

        #expect(!shouldScroll)
    }
}
