import Foundation
import Observation

@MainActor
@Observable
final class BrowserProfileStore {
    private enum Key {
        static let bookmarks = "browser.profile-directory-bookmarks.v1"
    }

    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored private let saveBookmarks: ([String: Data]) -> Void
    @ObservationIgnored private let preservesUnbookmarkedProfiles: Bool

    private(set) var bookmarks: [String: Data]
    private(set) var profilesByBrowserIdentifier: [String: [BrowserProfile]] = [:]
    private(set) var errorsByBrowserIdentifier: [String: String] = [:]

    init(
        bookmarks: [String: Data] = [:],
        profilesByBrowserIdentifier: [String: [BrowserProfile]] = [:],
        preservesUnbookmarkedProfiles: Bool = false,
        fileManager: FileManager = .default,
        saveBookmarks: @escaping ([String: Data]) -> Void = { _ in }
    ) {
        self.bookmarks = Dictionary(
            uniqueKeysWithValues: bookmarks.map {
                ($0.key.lowercased(), $0.value)
            }
        )
        self.profilesByBrowserIdentifier = Dictionary(
            uniqueKeysWithValues: profilesByBrowserIdentifier.map {
                ($0.key.lowercased(), $0.value)
            }
        )
        self.fileManager = fileManager
        self.preservesUnbookmarkedProfiles = preservesUnbookmarkedProfiles
        self.saveBookmarks = saveBookmarks
    }

    static func live(
        userDefaults: UserDefaults = .standard
    ) -> BrowserProfileStore {
        let bookmarks = userDefaults.dictionary(
            forKey: Key.bookmarks
        ) as? [String: Data] ?? [:]

        return BrowserProfileStore(
            bookmarks: bookmarks
        ) { bookmarks in
            userDefaults.set(
                bookmarks,
                forKey: Key.bookmarks
            )
        }
    }

    func isAuthorized(
        for bundleIdentifier: String
    ) -> Bool {
        let identifier = bundleIdentifier.lowercased()
        return bookmarks[identifier] != nil
            || (preservesUnbookmarkedProfiles && profilesByBrowserIdentifier[identifier] != nil)
    }

    func profiles(
        for bundleIdentifier: String
    ) -> [BrowserProfile] {
        profilesByBrowserIdentifier[bundleIdentifier.lowercased()] ?? []
    }

    func error(
        for bundleIdentifier: String
    ) -> String? {
        errorsByBrowserIdentifier[bundleIdentifier.lowercased()]
    }

    func refresh(
        for browser: BrowserApplication
    ) {
        let identifier = browser.browser.bundleIdentifier.lowercased()
        guard let support = BrowserProfileSupport.support(for: identifier) else {
            profilesByBrowserIdentifier[identifier] = []
            errorsByBrowserIdentifier[identifier] = nil
            return
        }

        guard let bookmark = bookmarks[identifier] else {
            if !preservesUnbookmarkedProfiles {
                profilesByBrowserIdentifier[identifier] = []
                errorsByBrowserIdentifier[identifier] = nil
            }
            return
        }

        do {
            var isStale = false
            let directory = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let didStartAccess = directory.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    directory.stopAccessingSecurityScopedResource()
                }
            }

            profilesByBrowserIdentifier[identifier] = try BrowserProfileParser.profiles(
                in: directory,
                family: support.family,
                fileManager: fileManager
            )
            errorsByBrowserIdentifier[identifier] = nil

            if isStale {
                bookmarks[identifier] = try directory.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                saveBookmarks(bookmarks)
            }
        } catch {
            profilesByBrowserIdentifier[identifier] = []
            errorsByBrowserIdentifier[identifier] = error.localizedDescription
        }
    }

    func grantAccess(
        to directory: URL,
        for browser: BrowserApplication
    ) throws {
        let identifier = browser.browser.bundleIdentifier.lowercased()
        guard let support = BrowserProfileSupport.support(for: identifier) else {
            return
        }

        let didStartAccess = directory.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                directory.stopAccessingSecurityScopedResource()
            }
        }

        let profiles = try BrowserProfileParser.profiles(
            in: directory,
            family: support.family,
            fileManager: fileManager
        )
        let bookmark = try directory.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        bookmarks[identifier] = bookmark
        profilesByBrowserIdentifier[identifier] = profiles
        errorsByBrowserIdentifier[identifier] = nil
        saveBookmarks(bookmarks)
    }

    func removeAccess(
        for bundleIdentifier: String
    ) {
        let identifier = bundleIdentifier.lowercased()
        bookmarks.removeValue(forKey: identifier)
        profilesByBrowserIdentifier.removeValue(forKey: identifier)
        errorsByBrowserIdentifier.removeValue(forKey: identifier)
        saveBookmarks(bookmarks)
    }

    func targets(
        for browsers: [BrowserApplication],
        includesArgumentTargets: Bool
    ) -> [BrowserLaunchTarget] {
        browsers.flatMap { browser in
            var targets = [
                BrowserLaunchTarget(
                    browser: browser,
                    kind: .standard
                ),
            ]

            guard
                includesArgumentTargets,
                let support = BrowserProfileSupport.support(
                    for: browser.browser.bundleIdentifier
                )
            else {
                return targets
            }

            targets.append(
                BrowserLaunchTarget(
                    browser: browser,
                    kind: .privateWindow(support.privateMode)
                )
            )
            targets.append(
                contentsOf: profiles(
                    for: browser.browser.bundleIdentifier
                ).map {
                    BrowserLaunchTarget(
                        browser: browser,
                        kind: .profile($0)
                    )
                }
            )
            return targets
        }
    }
}
