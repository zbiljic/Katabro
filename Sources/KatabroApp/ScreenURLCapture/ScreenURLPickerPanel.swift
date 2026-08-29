import AppKit
import SwiftUI

@MainActor
protocol ScreenURLPickerPresenting: AnyObject {
    func presentNearPointer()
    func close()
}

@MainActor
final class ScreenURLPickerPanel: NSPanel, ScreenURLPickerPresenting {
    static let contentSize = NSSize(width: 420, height: 400)

    private let onResign: () -> Void
    override var canBecomeKey: Bool {
        true
    }

    init(rootView: some View, onResign: @escaping () -> Void = {}) {
        self.onResign = onResign
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        contentViewController = NSHostingController(
            rootView: rootView.frame(
                width: Self.contentSize.width,
                height: Self.contentSize.height,
                alignment: .topLeading
            )
        )
        setContentSize(Self.contentSize)
        level = .floating
        collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
        backgroundColor = .clear
        hasShadow = true
        isOpaque = false
        title = "URLs Found on Screen"
    }

    override func resignKey() {
        super.resignKey()
        onResign()
    }

    func presentNearPointer() {
        positionNearPointer()
        orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    private func positionNearPointer() {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else {
            center()
            return
        }
        let origin = NSPoint(
            x: min(max(pointer.x - frame.width / 2, visible.minX + 8), visible.maxX - frame.width - 8),
            y: min(max(pointer.y - frame.height - 12, visible.minY + 8), visible.maxY - frame.height - 8)
        )
        setFrameOrigin(origin)
    }
}
