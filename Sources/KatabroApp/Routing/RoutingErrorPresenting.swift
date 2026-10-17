import AppKit

@MainActor
protocol RoutingErrorPresenting {
    func present(
        _ error: any Error
    )
}

@MainActor
struct AlertRoutingErrorPresenter: RoutingErrorPresenting {
    func present(
        _ error: any Error
    ) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Katabro Couldn’t Open This Link"
        alert.informativeText = error.localizedDescription
        let dismissButton = alert.addButton(
            withTitle: "Dismiss"
        )
        // Keep the default Return shortcut while also accepting Escape.
        let escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.window === alert.window, event.keyCode == 53 else { return event }
            dismissButton.performClick(nil)
            return nil
        }
        defer {
            if let escapeMonitor {
                NSEvent.removeMonitor(escapeMonitor)
            }
        }

        NSApplication.shared.activate()
        alert.runModal()
    }
}
