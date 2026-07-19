import KatabroCore
import Observation

@MainActor
@Observable
final class BrowserPickerStore {
    let destination: IncomingURL
    let browsers: [BrowserApplication]
    private(set) var selectedIndex: Int?

    var selectedBrowser: BrowserApplication? {
        guard let selectedIndex else {
            return nil
        }

        return browsers[selectedIndex]
    }

    init(
        destination: IncomingURL,
        browsers: [BrowserApplication]
    ) {
        self.destination = destination
        self.browsers = browsers
        selectedIndex = browsers.isEmpty ? nil : 0
    }

    func select(
        index: Int
    ) {
        guard browsers.indices.contains(index) else {
            return
        }

        selectedIndex = index
    }

    func moveSelection(
        by offset: Int
    ) {
        guard !browsers.isEmpty else {
            selectedIndex = nil
            return
        }

        guard let selectedIndex else {
            selectedIndex = offset < 0 ? browsers.index(before: browsers.endIndex) : browsers.startIndex
            return
        }

        let count = browsers.count
        self.selectedIndex = (selectedIndex + offset % count + count) % count
    }
}
