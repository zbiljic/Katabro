import AppKit
@testable import Katabro
import KatabroCore
import Testing

@MainActor
@Suite("Browser picker panel", .serialized)
struct BrowserPickerPanelTests {
    @Test("final panel and content fit all edges", arguments: [0, 5, 12], [false, true])
    func screenEdges(targetCount: Int, horizontal: Bool) async throws {
        let screen = try #require(NSScreen.main)
        let store = try makeStore(targetCount: targetCount, horizontal: horizontal)
        let layout = BrowserPickerLayout(
            preferences: store.pickerPreferences,
            targetCount: targetCount,
            includesRememberFooter: store.canRememberSelection
        )
        for size in [screen.visibleFrame.size, NSSize(width: 240, height: 200), NSSize(width: 90, height: 60)] {
            let visible = NSRect(origin: screen.visibleFrame.origin, size: size)
            for pointer in [
                NSPoint(x: visible.maxX - 1, y: visible.midY),
                NSPoint(x: visible.minX, y: visible.minY),
                NSPoint(x: visible.maxX - 1, y: visible.maxY - 1),
            ] {
                let panel = BrowserPickerPanel(
                    rootView: BrowserPickerView(store: store, onSelect: { _, _ in }, onCopyLink: {}, onCancel: {}),
                    layout: layout
                )
                defer { panel.close() }
                let initial = panel.frame
                panel.presentNearPointer(pointer: pointer, visibleFrame: visible)
                let presented = panel.frame
                await settle(panel)
                let expected = layout.fitting(in: layout.availableFrame(in: visible).size)
                #expect(panel.isVisible)
                #expect(panel.frame.minX >= visible.minX)
                #expect(panel.frame.maxX <= visible.maxX)
                #expect(panel.frame.minY >= visible.minY)
                #expect(panel.frame.maxY <= visible.maxY)
                #expect(panel.frame.width == expected.width)
                #expect(panel.frame.height == expected.height)
                #expect(panel.contentView?.frame.size == panel.frame.size)
                #expect(panel.frame == presented)
                #expect(initial.size == NSSize(width: layout.width, height: layout.height))
                #expect(store.pickerPreferences == layout.preferences)
                print(
                    "PICKER GEOMETRY initial=\(initial) presented=\(presented) final=\(panel.frame) visible=\(visible)"
                )
            }
        }
    }

    @Test("no screen still presents a correctly sized panel")
    func noScreen() async throws {
        let store = try makeStore(targetCount: 5, horizontal: false)
        let layout = BrowserPickerLayout(targetCount: 5, includesRememberFooter: true)
        let panel = BrowserPickerPanel(
            rootView: BrowserPickerView(store: store, onSelect: { _, _ in }, onCopyLink: {}, onCancel: {}),
            layout: layout
        )
        defer { panel.close() }
        panel.presentNearPointer(pointer: .zero, visibleFrame: nil)
        await settle(panel)
        #expect(panel.isVisible)
        #expect(panel.frame.size == NSSize(width: layout.width, height: layout.height))
    }

    @Test("tiny viewport retains keyboard selection, remember, activation and cancellation")
    func tinyViewportKeyboard() async throws {
        let screen = try #require(NSScreen.main)
        let store = try makeStore(targetCount: 12, horizontal: false)
        var selections = 0
        var selectedID: String?
        var remembered = false
        var cancellations = 0
        let panel = BrowserPickerPanel(
            rootView: BrowserPickerView(
                store: store,
                onSelect: { target, remembers in
                    selections += 1
                    selectedID = target.id
                    remembered = remembers
                },
                onCopyLink: {},
                onCancel: { cancellations += 1 }
            ),
            layout: BrowserPickerLayout(
                preferences: store.pickerPreferences, targetCount: 12, includesRememberFooter: true
            )
        )
        defer { panel.close() }
        let visible = NSRect(origin: screen.visibleFrame.origin, size: NSSize(width: 90, height: 60))
        panel.presentNearPointer(pointer: visible.origin, visibleFrame: visible)
        await settle(panel)
        for _ in 0 ..< 11 {
            try sendKey("\u{F701}", code: 125, to: panel)
        }
        await settle(panel)
        #expect(store.selectedIndex == 11)
        try sendKey("R", code: 15, modifiers: [.command, .shift], to: panel)
        try sendKey("\r", code: 36, to: panel)
        #expect(selections == 1)
        #expect(selectedID == store.targets.last?.id)
        #expect(remembered)
        try sendKey("\u{1B}", code: 53, to: panel)
        #expect(cancellations == 1)
        #expect(store.pickerPreferences.visibleChoiceCount == 8)
    }

    private func sendKey(
        _ characters: String, code: UInt16, modifiers: NSEvent.ModifierFlags = [], to panel: BrowserPickerPanel
    ) throws {
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters.lowercased(),
            isARepeat: false,
            keyCode: code
        ))
        panel.sendEvent(event)
    }

    private func settle(_ panel: BrowserPickerPanel) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
    }

    private func makeStore(targetCount: Int, horizontal: Bool) throws -> BrowserPickerStore {
        try BrowserPickerStore(
            destination: IncomingURL("https://example.com/long/destination"),
            browsers: (0 ..< targetCount).map { index in
                BrowserApplication(
                    browser: Browser(bundleIdentifier: "test.browser.\(index)", displayName: "Browser \(index)"),
                    applicationURL: URL(fileURLWithPath: "/Applications/Test.app"),
                    icon: NSImage(size: NSSize(width: 32, height: 32))
                )
            },
            pickerPreferences: BrowserPickerPreferences(
                orientation: horizontal ? .horizontal : .vertical,
                visibleChoiceCount: 8
            )
        )
    }
}
