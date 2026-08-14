import AppKit
import Foundation
import Observation

enum UserScriptBridgeError: LocalizedError {
    case applicationScriptsDirectoryUnavailable
    case bundledScriptMissing
    case incorrectInstallationLocation
    case scriptNotInstalled

    var errorDescription: String? {
        switch self {
        case .applicationScriptsDirectoryUnavailable:
            "Katabro’s Application Scripts folder could not be located."
        case .bundledScriptMissing:
            "Katabro’s bundled open.sh script is missing."
        case .incorrectInstallationLocation:
            "Choose the open.sh location already selected in Katabro’s Application Scripts folder."
        case .scriptNotInstalled:
            "Profile and private-window launching needs open.sh in Katabro’s "
                + "Application Scripts folder. Set it up in Browser Settings."
        }
    }
}

enum LauncherHelperInstallationState: Equatable {
    case missing
    case current
    case custom
}

@MainActor
@Observable
final class UserScriptBridge {
    static let scriptName = "open.sh"

    @ObservationIgnored private let bundle: Bundle
    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored private let installScriptHandler: (() throws -> Bool)?
    @ObservationIgnored private let fixedInstallationState: LauncherHelperInstallationState?

    private(set) var installationState = LauncherHelperInstallationState.missing

    var isInstalled: Bool {
        installationState != .missing
    }

    init(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        initialInstallationState: LauncherHelperInstallationState? = nil,
        installScriptHandler: (() throws -> Bool)? = nil
    ) {
        self.bundle = bundle
        self.fileManager = fileManager
        self.installScriptHandler = installScriptHandler
        fixedInstallationState = initialInstallationState
        if let initialInstallationState {
            installationState = initialInstallationState
        } else {
            refresh()
        }
    }

    func refresh() {
        if let fixedInstallationState {
            installationState = fixedInstallationState
            return
        }

        guard let installedScriptURL = try? installedScriptURL() else {
            installationState = .missing
            return
        }
        guard fileManager.isExecutableFile(atPath: installedScriptURL.path) else {
            installationState = .missing
            return
        }
        guard let bundledScriptURL = bundledScriptURL() else {
            installationState = .custom
            return
        }
        installationState = Self.installationState(
            installedScriptURL: installedScriptURL,
            bundledScriptURL: bundledScriptURL,
            fileManager: fileManager
        )
    }

    func installScript() throws -> Bool {
        if let installScriptHandler {
            return try installScriptHandler()
        }

        guard let bundledScriptURL = bundledScriptURL() else {
            throw UserScriptBridgeError.bundledScriptMissing
        }
        let installedScriptURL = try installedScriptURL()
        let panel = NSSavePanel()
        panel.directoryURL = installedScriptURL.deletingLastPathComponent()
        panel.nameFieldStringValue = Self.scriptName
        panel.title = isInstalled ? "Replace Launcher Helper" : "Install Launcher Helper"
        panel.message = "Save open.sh in Katabro’s Application Scripts folder."
        panel.prompt = isInstalled ? "Replace" : "Install"
        panel.canCreateDirectories = false
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return false
        }
        guard destinationURL.standardizedFileURL == installedScriptURL.standardizedFileURL else {
            throw UserScriptBridgeError.incorrectInstallationLocation
        }

        let stagedScriptURL = try Self.stageScript(
            from: bundledScriptURL,
            in: fileManager.temporaryDirectory,
            fileManager: fileManager
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
            _ = try fileManager.replaceItemAt(
                destinationURL,
                withItemAt: stagedScriptURL
            )
        } else {
            try fileManager.copyItem(
                at: stagedScriptURL,
                to: destinationURL
            )
        }
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: destinationURL.path
        )
        refresh()
        return true
    }

    func execute(
        arguments: [String]
    ) async throws {
        let scriptURL = try installedScriptURL()
        guard fileManager.isExecutableFile(atPath: scriptURL.path) else {
            throw UserScriptBridgeError.scriptNotInstalled
        }
        let task = try NSUserUnixTask(url: scriptURL)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            task.execute(withArguments: arguments) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func installedScriptURL() throws -> URL {
        try applicationScriptsDirectory().appendingPathComponent(
            Self.scriptName,
            isDirectory: false
        )
    }

    private func bundledScriptURL() -> URL? {
        bundle.url(
            forResource: "open",
            withExtension: "sh"
        )
    }

    private func applicationScriptsDirectory() throws -> URL {
        do {
            return try fileManager.url(
                for: .applicationScriptsDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            throw UserScriptBridgeError.applicationScriptsDirectoryUnavailable
        }
    }

    static func stageScript(
        from sourceURL: URL,
        in temporaryDirectory: URL,
        fileManager: FileManager
    ) throws -> URL {
        let stagingDirectory = temporaryDirectory
            .appendingPathComponent(
                "Katabro",
                isDirectory: true
            )
            .appendingPathComponent(
                "Launcher Helper",
                isDirectory: true
            )
        try fileManager.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: true
        )

        let stagedScriptURL = stagingDirectory.appendingPathComponent(
            Self.scriptName,
            isDirectory: false
        )
        if fileManager.fileExists(atPath: stagedScriptURL.path) {
            try fileManager.removeItem(at: stagedScriptURL)
        }
        try fileManager.copyItem(
            at: sourceURL,
            to: stagedScriptURL
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: stagedScriptURL.path
        )
        return stagedScriptURL
    }

    static func installationState(
        installedScriptURL: URL,
        bundledScriptURL: URL,
        fileManager: FileManager
    ) -> LauncherHelperInstallationState {
        guard fileManager.isExecutableFile(atPath: installedScriptURL.path) else {
            return .missing
        }

        guard
            let installedData = try? Data(contentsOf: installedScriptURL),
            let bundledData = try? Data(contentsOf: bundledScriptURL),
            installedData == bundledData
        else {
            return .custom
        }
        return .current
    }
}
