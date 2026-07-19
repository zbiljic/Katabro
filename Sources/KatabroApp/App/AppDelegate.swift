import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let dependencies = AppDependencies.live

    lazy var pickerCoordinator = BrowserPickerCoordinator(
        dependencies: dependencies
    )

    func application(
        _: NSApplication,
        open urls: [URL]
    ) {
        pickerCoordinator.handle(urls)
    }
}
