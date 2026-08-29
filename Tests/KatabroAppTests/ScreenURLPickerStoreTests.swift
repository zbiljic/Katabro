@testable import Katabro
import KatabroCore
import Testing

@MainActor
@Suite("Screen URL picker store")
struct ScreenURLPickerStoreTests {
    @Test("all non-result states begin without a selection")
    func nonResultStates() {
        for state in [
            ScreenURLPickerStore.State.loading, .empty, .permissionRequired, .captureFailed, .visionUnavailable,
        ] {
            let store = ScreenURLPickerStore(state: state)
            #expect(store.selection == nil)
            #expect(store.results.isEmpty)
        }
    }

    @Test("initializes empty and nonempty results correctly")
    func initialSelection() throws {
        #expect(ScreenURLPickerStore(state: .results([])).selection == nil)
        #expect(try ScreenURLPickerStore(state: .results(urls())).selection == .url(0))
    }

    @Test("wraps forward and backward across URL rows and Open all")
    func wrapsSelection() throws {
        let store = try ScreenURLPickerStore(state: .results(urls()))
        store.moveSelection(by: -1)
        #expect(store.selection == .all)
        store.moveSelection(by: 1)
        #expect(store.selection == .url(0))
        store.moveSelection(by: 3)
        #expect(store.selection == .url(0))
    }

    @Test("only exposes Open all for two or more URLs and supports zero semantics")
    func openAllThresholdAndZeroSemantics() throws {
        let single = try ScreenURLPickerStore(state: .results([url("https://one.example")]))
        single.selectOpenAll()
        #expect(!single.supportsOpenAll)
        #expect(single.selection == .url(0))
        let multiple = try ScreenURLPickerStore(state: .results(urls()))
        multiple.selectOpenAll()
        #expect(multiple.supportsOpenAll)
        #expect(multiple.selection == .all)
    }

    @Test("ignores invalid indexes and resets state replacement selection")
    func invalidIndexAndReplacement() throws {
        let store = try ScreenURLPickerStore(state: .results(urls()))
        store.select(index: 99)
        #expect(store.selection == .url(0))
        let firstID = store.results[0].id
        try store.replaceState(with: .results([url("https://three.example")]))
        #expect(store.selection == .url(0))
        #expect(store.results[0].id != firstID)
        store.replaceState(with: .empty)
        #expect(store.selection == nil)
    }

    @Test("keeps URL identity stable across equivalent state replacement")
    func stableIdentity() throws {
        let value = try url("https://one.example")
        let store = ScreenURLPickerStore(state: .results([value]))
        store.replaceState(with: .results([value]))
        #expect(store.results[0].id == value.id)
    }

    @Test("caps Retina capture dimensions while preserving aspect ratio")
    func captureImageSizeCap() {
        #expect(ScreenCaptureImageSize.size(width: 10240, height: 5120) == .init(width: 5120, height: 2560))
        #expect(ScreenCaptureImageSize.size(width: 100, height: 50) == .init(width: 100, height: 50))
        #expect(ScreenCaptureImageSize.size(width: 0, height: 0) == .init(width: 1, height: 1))
    }

    private func urls() throws -> [DetectedURL] {
        try [url("https://one.example"), url("https://two.example")]
    }

    private func url(_ value: String) throws -> DetectedURL {
        try DetectedURL(destination: IncomingURL(value))
    }
}
