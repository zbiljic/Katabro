import AppKit
import Foundation

/// The folder chooser is deliberately a tiny injected seam.  It owns neither
/// disclosure UI nor preference persistence, which keeps review fixtures safe.
@MainActor
final class ConfigurationFolderClient {
    typealias ChooseDirectory = @MainActor () -> URL?
    typealias MakeClient = @MainActor (URL) -> FilePreferencesClient

    private let chooseDirectoryClosure: ChooseDirectory
    private let makeClientClosure: MakeClient

    init(
        chooseDirectory: @escaping ChooseDirectory,
        makeClient: @escaping MakeClient = { url in FilePreferencesClient(directoryURL: url) }
    ) {
        chooseDirectoryClosure = chooseDirectory
        makeClientClosure = makeClient
    }

    func chooseDirectory() -> URL? {
        chooseDirectoryClosure()
    }

    func makeClient(for url: URL) -> FilePreferencesClient {
        makeClientClosure(url)
    }

    static var live: ConfigurationFolderClient {
        ConfigurationFolderClient {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = false
            panel.prompt = "Choose"
            return panel.runModal() == .OK ? panel.url : nil
        }
    }
}
