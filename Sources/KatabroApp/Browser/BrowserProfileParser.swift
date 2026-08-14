import Foundation
import SQLite3

enum BrowserProfileParserError: LocalizedError, Equatable {
    case invalidChromiumLocalState
    case missingChromiumLocalState
    case missingFirefoxProfiles
    case invalidFirefoxProfileStore

    var errorDescription: String? {
        switch self {
        case .invalidChromiumLocalState:
            "The selected folder contains an unreadable Chromium Local State file."
        case .missingChromiumLocalState:
            "Choose the browser data folder that contains Local State."
        case .missingFirefoxProfiles:
            "Choose the Firefox folder that contains profiles.ini."
        case .invalidFirefoxProfileStore:
            "Firefox’s profile group database could not be read."
        }
    }
}

enum BrowserProfileParser {
    static func profiles(
        in directory: URL,
        family: BrowserFamily,
        fileManager: FileManager = .default
    ) throws -> [BrowserProfile] {
        switch family {
        case .chromium:
            try chromiumProfiles(
                in: directory,
                fileManager: fileManager
            )
        case .firefox:
            try firefoxProfiles(
                in: directory,
                fileManager: fileManager
            )
        }
    }

    private static func chromiumProfiles(
        in directory: URL,
        fileManager: FileManager
    ) throws -> [BrowserProfile] {
        let localStateURL = directory.appendingPathComponent(
            "Local State",
            isDirectory: false
        )

        guard fileManager.fileExists(atPath: localStateURL.path) else {
            throw BrowserProfileParserError.missingChromiumLocalState
        }

        let data = try Data(contentsOf: localStateURL)
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let profile = root["profile"] as? [String: Any],
            let infoCache = profile["info_cache"] as? [String: Any]
        else {
            throw BrowserProfileParserError.invalidChromiumLocalState
        }

        return infoCache.compactMap { directoryName, value in
            guard let metadata = value as? [String: Any] else {
                return nil
            }

            let name = (metadata["name"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = name.flatMap {
                $0.isEmpty ? nil : $0
            } ?? directoryName

            return BrowserProfile(
                identifier: directoryName,
                displayName: displayName,
                launchValue: directoryName,
                family: .chromium
            )
        }
        .sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    // Parsing the INI sections and choosing the modern or legacy store is one transaction.
    // swiftlint:disable:next function_body_length
    private static func firefoxProfiles(
        in directory: URL,
        fileManager: FileManager
    ) throws -> [BrowserProfile] {
        let profilesURL = directory.appendingPathComponent(
            "profiles.ini",
            isDirectory: false
        )

        guard fileManager.fileExists(atPath: profilesURL.path) else {
            throw BrowserProfileParserError.missingFirefoxProfiles
        }

        let contents = try String(
            contentsOf: profilesURL,
            encoding: .utf8
        )
        var sections: [[String: String]] = []
        var currentSection: [String: String]?

        for rawLine in contents.split(
            whereSeparator: \Character.isNewline
        ) {
            let line = rawLine.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if line.hasPrefix("["), line.hasSuffix("]") {
                if let currentSection {
                    sections.append(currentSection)
                }
                currentSection = line.hasPrefix("[Profile") ? [:] : nil
                continue
            }

            guard
                currentSection != nil,
                let separator = line.firstIndex(of: "=")
            else {
                continue
            }

            let key = String(line[..<separator])
            let value = String(line[line.index(after: separator)...])
            currentSection?[key] = value
        }

        if let currentSection {
            sections.append(currentSection)
        }

        let modernProfiles = try sections
            .compactMap { $0["StoreID"] }
            .reduce(into: Set<String>()) { $0.insert($1) }
            .flatMap {
                try firefoxProfiles(
                    in: directory,
                    storeID: $0,
                    fileManager: fileManager
                )
            }

        if !modernProfiles.isEmpty {
            return modernProfiles.sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
        }

        return sections.compactMap { values in
            guard
                let path = values["Path"],
                !path.isEmpty
            else {
                return nil
            }

            let profileURL = values["IsRelative"] == "0"
                ? URL(fileURLWithPath: path, isDirectory: true)
                : directory.appendingPathComponent(path, isDirectory: true)
            let name = values["Name"]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = name.flatMap {
                $0.isEmpty ? nil : $0
            } ?? profileURL.lastPathComponent

            return BrowserProfile(
                identifier: path,
                displayName: displayName,
                launchValue: profileURL.path,
                family: .firefox
            )
        }
        .sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    // SQLite lifetime and row validation intentionally remain in the same scope.
    // swiftlint:disable:next function_body_length
    private static func firefoxProfiles(
        in directory: URL,
        storeID: String,
        fileManager: FileManager
    ) throws -> [BrowserProfile] {
        let databaseURL = directory
            .appendingPathComponent("Profile Groups", isDirectory: true)
            .appendingPathComponent("\(storeID).sqlite", isDirectory: false)

        guard fileManager.fileExists(atPath: databaseURL.path) else {
            return []
        }

        var database: OpaquePointer?
        guard
            sqlite3_open_v2(
                databaseURL.path,
                &database,
                SQLITE_OPEN_READONLY,
                nil
            ) == SQLITE_OK
        else {
            sqlite3_close(database)
            throw BrowserProfileParserError.invalidFirefoxProfileStore
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard
            sqlite3_prepare_v2(
                database,
                "SELECT path, name FROM Profiles ORDER BY id",
                -1,
                &statement,
                nil
            ) == SQLITE_OK
        else {
            throw BrowserProfileParserError.invalidFirefoxProfileStore
        }
        defer { sqlite3_finalize(statement) }

        let standardizedRoot = directory.standardizedFileURL
        var profiles: [BrowserProfile] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let pathText = sqlite3_column_text(statement, 0),
                let nameText = sqlite3_column_text(statement, 1)
            else {
                continue
            }

            let path = String(cString: pathText)
            let name = String(cString: nameText)
            let profileURL = standardizedRoot
                .appendingPathComponent(path, isDirectory: true)
                .standardizedFileURL

            guard
                profileURL.path == standardizedRoot.path
                || profileURL.path.hasPrefix(standardizedRoot.path + "/")
            else {
                continue
            }

            profiles.append(
                BrowserProfile(
                    identifier: path,
                    displayName: name,
                    launchValue: profileURL.path,
                    family: .firefox
                )
            )
        }

        guard
            sqlite3_errcode(database) == SQLITE_OK
            || sqlite3_errcode(database) == SQLITE_DONE
        else {
            throw BrowserProfileParserError.invalidFirefoxProfileStore
        }

        return profiles
    }
}
