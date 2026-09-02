import AppKit
import SwiftUI

enum OnboardingLaunchPolicy {
    static func shouldPresent(
        hasCompletedOnboarding: Bool
    ) -> Bool {
        !hasCompletedOnboarding
    }
}

@MainActor
final class OnboardingWindowCoordinator: NSObject, NSWindowDelegate {
    private let defaultBrowserClient: DefaultBrowserClient
    private let preferencesStore: PreferencesStore
    private let clipboardURLShortcutSettings: GlobalShortcutSettings
    private var window: NSWindow?

    init(
        defaultBrowserClient: DefaultBrowserClient,
        preferencesStore: PreferencesStore,
        clipboardURLShortcutSettings: GlobalShortcutSettings
    ) {
        self.defaultBrowserClient = defaultBrowserClient
        self.preferencesStore = preferencesStore
        self.clipboardURLShortcutSettings = clipboardURLShortcutSettings
    }

    func presentIfNeeded() {
        guard
            OnboardingLaunchPolicy.shouldPresent(
                hasCompletedOnboarding: preferencesStore.hasCompletedOnboarding
            )
        else {
            return
        }

        present()
    }

    func present() {
        if let window {
            NSApplication.shared.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }

        let view = OnboardingView(
            defaultBrowserClient: defaultBrowserClient,
            preferencesStore: preferencesStore,
            clipboardURLShortcutSettings: clipboardURLShortcutSettings
        ) { [weak self] in
            self?.window?.close()
        }
        let window = NSWindow(
            contentRect: NSRect(
                origin: .zero,
                size: NSSize(
                    width: 520,
                    height: 360
                )
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
            ],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = NSHostingController(
            rootView: view
        )
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.title = "Welcome to Katabro"
        window.center()

        self.window = window
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(
        _: Notification
    ) {
        window = nil
    }
}
