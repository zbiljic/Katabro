@testable import Katabro
import Testing

@Suite("Browser picker layout")
struct BrowserPickerLayoutTests {
    @Test("omitting the Remember footer removes its exact height")
    func omitsRememberFooter() {
        let withFooter = BrowserPickerLayout.height(
            browserCount: 4,
            includesRememberFooter: true
        )
        let withoutFooter = BrowserPickerLayout.height(
            browserCount: 4,
            includesRememberFooter: false
        )

        let expectedWithFooter = withoutFooter + BrowserPickerLayout.rememberFooterHeight

        #expect(
            Double(withFooter).bitPattern
                == Double(expectedWithFooter).bitPattern
        )
        #expect(
            BrowserPickerLayout.height(browserCount: 0, includesRememberFooter: false)
                == BrowserPickerLayout.minimumHeight
        )
        #expect(
            BrowserPickerLayout.height(browserCount: 1, includesRememberFooter: false)
                == BrowserPickerLayout.minimumHeight
        )
    }
}
