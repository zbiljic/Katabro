import AppKit
@testable import Katabro
import Testing

@MainActor
@Suite("Routing error alert", .serialized)
struct RoutingErrorPresenterTests {
    @Test("Escape dismisses the alert")
    func escapeDismissal() {
        var sentKey = false
        var timedOut = false
        let timeout = Timer(timeInterval: 2, repeats: false) { _ in
            MainActor.assumeIsolated {
                timedOut = true
                NSApplication.shared.abortModal()
            }
        }
        let keyTimer = Timer(timeInterval: 0.01, repeats: false) { _ in
            MainActor.assumeIsolated {
                guard let window = NSApplication.shared.modalWindow else { return }
                guard
                    let event = NSEvent.keyEvent(
                        with: .keyDown,
                        location: .zero,
                        modifierFlags: [],
                        timestamp: 0,
                        windowNumber: window.windowNumber,
                        context: nil,
                        characters: "\u{1b}",
                        charactersIgnoringModifiers: "\u{1b}",
                        isARepeat: false,
                        keyCode: 53
                    ) else { return }
                sentKey = true
                NSApplication.shared.postEvent(event, atStart: true)
            }
        }
        defer {
            timeout.invalidate()
            keyTimer.invalidate()
        }
        RunLoop.main.add(timeout, forMode: .modalPanel)
        RunLoop.main.add(keyTimer, forMode: .modalPanel)

        AlertRoutingErrorPresenter().present(NSError(domain: "RoutingErrorPresenterTests", code: 1))

        #expect(sentKey)
        #expect(!timedOut)
        #expect(NSApplication.shared.modalWindow == nil)
    }
}
