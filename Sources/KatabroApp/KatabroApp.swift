import AppKit
import SwiftUI

@main
struct KatabroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        MenuBarExtra(
            AppMetadata.displayName,
            systemImage: "arrow.triangle.branch"
        ) {
            Text("Katabro is ready")

            Divider()

            Button("Quit Katabro") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
