import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let pickerCoordinator = BrowserPickerCoordinator(
        dependencies: .live
    )

    func application(
        _: NSApplication,
        open urls: [URL]
    ) {
        pickerCoordinator.handle(urls)
    }
}
