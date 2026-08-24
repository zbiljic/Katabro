import Foundation
@testable import Katabro
import Testing

@MainActor
private final class ClipboardSnapshotFixtureState {
    var changeCount = 1
    var currentURL = URL(string: "https://example.com/first")
    var readCount = 0
}

@MainActor
@Suite("Clipboard URL snapshot store")
struct ClipboardURLSnapshotStoreTests {
    @Test("refresh captures one clipboard value for preview and routing")
    func capturesClipboardURL() {
        var currentURL = URL(string: "https://example.com/first")
        var readCount = 0
        let store = ClipboardURLSnapshotStore(
            clipboardURLClient: ClipboardURLClient {
                readCount += 1
                return currentURL
            }
        )

        store.refresh()
        currentURL = URL(string: "https://example.com/second")

        #expect(readCount == 1)
        #expect(store.url == URL(string: "https://example.com/first"))
        #expect(store.displayText == "https://example.com/first")
    }

    @Test("refresh replaces a stale snapshot")
    func replacesClipboardURL() {
        var currentURL = URL(string: "https://example.com/first")
        let store = ClipboardURLSnapshotStore(
            clipboardURLClient: ClipboardURLClient {
                currentURL
            }
        )

        store.refresh()
        currentURL = URL(string: "https://example.com/second")
        store.refresh()

        #expect(store.url == URL(string: "https://example.com/second"))
        #expect(store.displayText == "https://example.com/second")
    }

    @Test("refresh clears a snapshot when the clipboard is no longer routable")
    func clearsClipboardURL() {
        var currentURL = URL(string: "https://example.com")
        let store = ClipboardURLSnapshotStore(
            clipboardURLClient: ClipboardURLClient {
                currentURL
            }
        )

        store.refresh()
        currentURL = nil
        store.refresh()

        #expect(store.url == nil)
        #expect(store.displayText == nil)
    }

    @Test("unchanged clipboard generations do not reread their contents")
    func skipsUnchangedClipboardGeneration() {
        let state = ClipboardSnapshotFixtureState()
        let store = ClipboardURLSnapshotStore(
            clipboardURLClient: ClipboardURLClient(
                currentURLHandler: {
                    state.readCount += 1
                    return state.currentURL
                },
                changeCountHandler: {
                    state.changeCount
                }
            )
        )

        store.refreshIfNeeded()
        state.currentURL = URL(string: "https://example.com/second")
        store.refreshIfNeeded()

        #expect(state.readCount == 1)
        #expect(store.url == URL(string: "https://example.com/first"))

        state.changeCount += 1
        store.refreshIfNeeded()

        #expect(state.readCount == 2)
        #expect(store.url == URL(string: "https://example.com/second"))
    }

    @Test("long previews preserve both ends of the URL")
    func truncatesLongClipboardURL() {
        let store = ClipboardURLSnapshotStore(
            clipboardURLClient: .development(
                url: URL(
                    string: "https://documentation.preview.long-subdomain.example.com/guides/browser-routing?source=clipboard-fixture"
                )
            )
        )

        store.refresh()

        #expect(
            store.displayText
                == "https://documentation.previ…ing?source=clipboard-fixture"
        )
    }
}
