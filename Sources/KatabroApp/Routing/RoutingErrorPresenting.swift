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
        alert.addButton(
            withTitle: "Dismiss"
        )

        NSApplication.shared.activate()
        alert.runModal()
    }
}
