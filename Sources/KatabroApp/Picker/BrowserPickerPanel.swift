import AppKit
import SwiftUI

@MainActor
final class BrowserPickerPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    init(
        rootView: some View,
        browserCount: Int
    ) {
        let height = BrowserPickerLayout.height(
            browserCount: browserCount
        )

        super.init(
            contentRect: NSRect(
                origin: .zero,
                size: NSSize(
                    width: BrowserPickerLayout.width,
                    height: height
                )
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        contentViewController = NSHostingController(
            rootView: rootView
                .frame(
                    minHeight: CGFloat(height),
                    alignment: .top
                )
        )
        level = .floating
        collectionBehavior = [
            .transient,
            .moveToActiveSpace,
            .fullScreenAuxiliary,
        ]
        animationBehavior = .utilityWindow
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        isOpaque = false
        title = "Choose a browser"
    }

    func presentNearPointer() {
        positionNearPointer()
        NSApplication.shared.activate()
        makeKeyAndOrderFront(nil)
    }

    private func positionNearPointer() {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { screen in
            screen.frame.contains(pointer)
        } ?? NSScreen.main

        guard let visibleFrame = screen?.visibleFrame else {
            center()
            return
        }

        let horizontalInset: CGFloat = 8
        let verticalInset: CGFloat = 8
        let maximumX = max(
            visibleFrame.minX + horizontalInset,
            visibleFrame.maxX - frame.width - horizontalInset
        )
        let maximumY = max(
            visibleFrame.minY + verticalInset,
            visibleFrame.maxY - frame.height - verticalInset
        )
        let proposedX = pointer.x - frame.width / 2
        var proposedY = pointer.y - frame.height - 12

        if proposedY < visibleFrame.minY + verticalInset {
            proposedY = pointer.y + 12
        }

        setFrameOrigin(
            NSPoint(
                x: min(
                    max(proposedX, visibleFrame.minX + horizontalInset),
                    maximumX
                ),
                y: min(
                    max(proposedY, visibleFrame.minY + verticalInset),
                    maximumY
                )
            )
        )
    }
}
