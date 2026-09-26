import AppKit
import SwiftUI

@MainActor
final class BrowserPickerPanel: NSPanel {
    private let preferredLayout: BrowserPickerLayout
    private let hostingController: NSHostingController<BrowserPickerView>

    override var canBecomeKey: Bool {
        true
    }

    init(
        rootView: BrowserPickerView,
        layout: BrowserPickerLayout
    ) {
        preferredLayout = layout
        hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = []
        super.init(
            contentRect: NSRect(
                origin: .zero,
                size: NSSize(
                    width: layout.width,
                    height: layout.height
                )
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        contentViewController = hostingController
        setContentSize(NSSize(width: layout.width, height: layout.height))
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
        var pointer = NSEvent.mouseLocation
        #if DEBUG
            if let configuration = DevelopmentUIConfiguration.current() {
                switch configuration.appearance {
                case .light: appearance = NSAppearance(named: .aqua)
                case .dark: appearance = NSAppearance(named: .darkAqua)
                case .system: break
                }
                if let screen = NSScreen.screens.first {
                    pointer = configuration.pickerPointer(in: screen.frame) ?? pointer
                }
            }
        #endif
        let screens = NSScreen.screens
        let index = BrowserPickerLayout.screenIndex(
            near: pointer,
            frames: screens.map(\.frame),
            mainIndex: screens.firstIndex { $0 == NSScreen.main }
        )
        let screen = index.map { screens[$0] }
        presentNearPointer(pointer: pointer, visibleFrame: screen?.visibleFrame)
    }

    func presentNearPointer(pointer: NSPoint, visibleFrame: NSRect?) {
        positionNearPointer(pointer: pointer, visibleFrame: visibleFrame)
        NSApplication.shared.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    private func positionNearPointer(pointer: NSPoint, visibleFrame: NSRect?) {
        guard let visibleFrame else {
            center()
            return
        }

        let bounds = preferredLayout.availableFrame(in: visibleFrame)
        let layout = preferredLayout.fitting(in: bounds.size)
        hostingController.rootView.presentationLayout = layout
        setContentSize(NSSize(width: layout.width, height: layout.height))
        contentView?.layoutSubtreeIfNeeded()
        setFrame(layout.frame(near: pointer, in: bounds), display: false)
    }
}
