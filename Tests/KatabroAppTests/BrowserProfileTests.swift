import AppKit
@testable import Katabro
import KatabroCore
import SQLite3
import Testing

// Browser profile parsing scenarios intentionally share fixture helpers.
// swiftlint:disable type_body_length
@Suite("Browser profiles")
struct BrowserProfileTests {
    @Test("parses and sorts Chromium profile metadata")
    func parsesChromiumProfiles() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let localState = """
        {
          "profile": {
            "info_cache": {
              "Profile 2": { "name": "Work" },
              "Default": { "name": "Personal" }
            }
          }
        }
        """
        try Data(localState.utf8).write(
            to: directory.appendingPathComponent("Local State")
        )

        let profiles = try BrowserProfileParser.profiles(
            in: directory,
            family: .chromium
        )

        #expect(profiles.map(\.displayName) == ["Personal", "Work"])
        #expect(profiles.map(\.launchValue) == ["Default", "Profile 2"])
    }

    @Test("parses legacy Firefox profiles")
    func parsesLegacyFirefoxProfiles() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let profilesINI = """
        [Profile0]
        Name=Personal
        IsRelative=1
        Path=Profiles/abc.personal

        [Profile1]
        Name=Work
        IsRelative=0
        Path=/tmp/firefox-work
        """
        try Data(profilesINI.utf8).write(
            to: directory.appendingPathComponent("profiles.ini")
        )

        let profiles = try BrowserProfileParser.profiles(
            in: directory,
            family: .firefox
        )

        #expect(profiles.map(\.displayName) == ["Personal", "Work"])
        #expect(profiles[0].launchValue.hasSuffix("/Profiles/abc.personal"))
        #expect(profiles[1].launchValue == "/tmp/firefox-work")
    }

    @Test("prefers Firefox profile groups and rejects escaping paths")
    func parsesFirefoxProfileGroups() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent("Profile Groups"),
            withIntermediateDirectories: true
        )
        let profilesINI = """
        [Profile0]
        Name=Legacy
        IsRelative=1
        Path=Profiles/legacy
        StoreID=group123
        """
        try Data(profilesINI.utf8).write(
            to: directory.appendingPathComponent("profiles.ini")
        )
        let databaseURL = directory
            .appendingPathComponent("Profile Groups")
            .appendingPathComponent("group123.sqlite")
        try createFirefoxProfileDatabase(at: databaseURL)

        let profiles = try BrowserProfileParser.profiles(
            in: directory,
            family: .firefox
        )

        #expect(profiles.map(\.displayName) == ["Developer"])
        #expect(profiles[0].launchValue.hasSuffix("/Profiles/dev"))
    }

    @MainActor
    @Test("constructs structured private and profile arguments")
    func constructsLaunchArguments() throws {
        let destination = try IncomingURL("https://example.com/path?q=hello world")
        let browser = browserApplication()
        let privateTarget = BrowserLaunchTarget(
            browser: browser,
            kind: .privateWindow(.chromium)
        )
        let profileTarget = BrowserLaunchTarget(
            browser: browser,
            kind: .profile(
                BrowserProfile(
                    identifier: "Profile 2",
                    displayName: "Work",
                    launchValue: "Profile 2",
                    family: .chromium
                )
            )
        )
        let firefoxTarget = BrowserLaunchTarget(
            browser: browser,
            kind: .profile(
                BrowserProfile(
                    identifier: "Profiles/work",
                    displayName: "Work",
                    launchValue: "/Browser Data/Profiles/work",
                    family: .firefox
                )
            )
        )

        #expect(
            privateTarget.browserArguments(for: destination) == [
                "--incognito",
                destination.url.absoluteString,
            ]
        )
        #expect(
            profileTarget.browserArguments(for: destination) == [
                "--profile-directory=Profile 2",
                destination.url.absoluteString,
            ]
        )
        #expect(
            firefoxTarget.browserArguments(for: destination) == [
                "-profile",
                "/Browser Data/Profiles/work",
                "-no-remote",
                destination.url.absoluteString,
            ]
        )
    }

    @MainActor
    @Test("keeps standard, private, and profile target identifiers distinct")
    func keepsLaunchTargetIdentifiersStable() {
        let browser = browserApplication()
        let standard = BrowserLaunchTarget(browser: browser, kind: .standard)
        let privateWindow = BrowserLaunchTarget(
            browser: browser,
            kind: .privateWindow(.chromium)
        )
        let profile = BrowserLaunchTarget(
            browser: browser,
            kind: .profile(
                BrowserProfile(
                    identifier: "Mixed Case/Profile ",
                    displayName: "Work",
                    launchValue: "Mixed Case/Profile ",
                    family: .chromium
                )
            )
        )

        #expect(standard.id == "com.google.chrome")
        #expect(privateWindow.id == "com.google.chrome:private")
        #expect(profile.id == "com.google.chrome:profile:Mixed Case/Profile ")
        #expect(Set([standard.id, privateWindow.id, profile.id]).count == 3)
    }

    @Test(
        "maps supported browsers to their family and profile directory",
        arguments: [
            ("com.google.Chrome", BrowserFamily.chromium, "Google/Chrome"),
            ("com.google.Chrome.dev", .chromium, "Google/Chrome Dev"),
            ("com.brave.Browser", .chromium, "BraveSoftware/Brave-Browser"),
            ("com.microsoft.edgemac.Beta", .chromium, "Microsoft Edge Beta"),
            ("com.vivaldi.Vivaldi", .chromium, "Vivaldi"),
            ("net.imput.helium", .chromium, "net.imput.helium"),
            ("com.operasoftware.OperaGX", .chromium, "com.operasoftware.OperaGX"),
            ("org.mozilla.firefox", .firefox, "Firefox"),
            ("org.mozilla.firefoxdeveloperedition", .firefox, "Firefox"),
            ("app.zen-browser.zen", .firefox, "zen"),
            ("app.glide-browser.glide", .firefox, "glide"),
        ]
    )
    func mapsSupportedBrowsers(
        bundleIdentifier: String,
        family: BrowserFamily,
        relativeDirectory: String
    ) throws {
        let support = try #require(
            BrowserProfileSupport.support(for: bundleIdentifier)
        )

        #expect(support.family == family)
        #expect(
            support.suggestedDirectory
                == "~/Library/Application Support/\(relativeDirectory)"
        )
    }

    @Test("uses Opera's private-mode argument")
    func mapsOperaPrivateMode() throws {
        let support = try #require(
            BrowserProfileSupport.support(for: "com.operasoftware.Opera")
        )

        #expect(support.privateMode.arguments == ["--private"])
    }

    @Test("requires exact browser bundle identifiers")
    func rejectsUnsupportedBrowsers() {
        #expect(BrowserProfileSupport.support(for: "com.google.Chrome.helper") == nil)
        #expect(BrowserProfileSupport.support(for: "com.example.chromium-browser") == nil)
    }

    @MainActor
    @Test("stages and recreates an executable copy without moving the bundled script")
    func stagesLauncherScript() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("bundled-open.sh")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: sourceURL)

        let stagedURL = try UserScriptBridge.stageScript(
            from: sourceURL,
            in: directory.appendingPathComponent("temporary", isDirectory: true),
            fileManager: .default
        )

        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(FileManager.default.isExecutableFile(atPath: stagedURL.path))
        #expect(try Data(contentsOf: stagedURL) == Data(contentsOf: sourceURL))

        let movedURL = directory.appendingPathComponent("moved-open.sh")
        try FileManager.default.moveItem(
            at: stagedURL,
            to: movedURL
        )
        let recreatedURL = try UserScriptBridge.stageScript(
            from: sourceURL,
            in: directory.appendingPathComponent("temporary", isDirectory: true),
            fileManager: .default
        )

        #expect(FileManager.default.fileExists(atPath: movedURL.path))
        #expect(FileManager.default.isExecutableFile(atPath: recreatedURL.path))
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    @MainActor
    @Test("distinguishes missing, current, and custom launcher helpers")
    func detectsLauncherScriptState() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bundledURL = directory.appendingPathComponent("bundled-open.sh")
        let installedURL = directory.appendingPathComponent("installed-open.sh")
        let bundledData = Data("#!/bin/sh\nexit 0\n".utf8)
        try bundledData.write(to: bundledURL)

        #expect(
            UserScriptBridge.installationState(
                installedScriptURL: installedURL,
                bundledScriptURL: bundledURL,
                fileManager: .default
            ) == .missing
        )

        try bundledData.write(to: installedURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: installedURL.path
        )
        #expect(
            UserScriptBridge.installationState(
                installedScriptURL: installedURL,
                bundledScriptURL: bundledURL,
                fileManager: .default
            ) == .current
        )

        try Data("#!/bin/sh\nexit 1\n".utf8).write(to: installedURL)
        #expect(
            UserScriptBridge.installationState(
                installedScriptURL: installedURL,
                bundledScriptURL: bundledURL,
                fileManager: .default
            ) == .custom
        )
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func createFirefoxProfileDatabase(
        at url: URL
    ) throws {
        var database: OpaquePointer?
        try #require(sqlite3_open(url.path, &database) == SQLITE_OK)
        defer { sqlite3_close(database) }
        try #require(
            sqlite3_exec(
                database,
                "CREATE TABLE Profiles (id INTEGER PRIMARY KEY, path TEXT, name TEXT);",
                nil,
                nil,
                nil
            ) == SQLITE_OK
        )
        try #require(
            sqlite3_exec(
                database,
                "INSERT INTO Profiles VALUES (1, 'Profiles/dev', 'Developer');"
                    + "INSERT INTO Profiles VALUES (2, '../escape', 'Escape');",
                nil,
                nil,
                nil
            ) == SQLITE_OK
        )
    }

    @MainActor
    private func browserApplication() -> BrowserApplication {
        BrowserApplication(
            browser: Browser(
                bundleIdentifier: "com.google.Chrome",
                displayName: "Google Chrome"
            ),
            applicationURL: URL(fileURLWithPath: "/Applications/Google Chrome.app"),
            icon: NSImage(size: NSSize(width: 32, height: 32))
        )
    }
}

// swiftlint:enable type_body_length
