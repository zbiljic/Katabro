import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let pickerCoordinator = BrowserPickerCoordinator(
        dependencies: .live
    )

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func application(
        _: NSApplication,
        open urls: [URL]
    ) {
        pickerCoordinator.handle(urls)
    }

    func applicationWillTerminate(
        _ notification: Notification
    ) {
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc
    private func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        replyEvent: NSAppleEventDescriptor
    ) {
        guard
            let value = event.paramDescriptor(
                forKeyword: AEKeyword(keyDirectObject)
            )?.stringValue,
            let url = URL(string: value)
        else {
            return
        }

        pickerCoordinator.handle(url)
    }
}
