import Darwin
import Foundation
@testable import Katabro
import KatabroCore
import os
import Testing

@MainActor
@Suite("Folder settings snapshot")
struct FilePreferencesClientTests { // swiftlint:disable:this type_body_length
    @Test("encodes a canonical version one document")
    func canonicalDocument() throws {
        let targetIdentifier = "com.example.browser:profile:opaque-profile-id"
        let rule = try #require(ExactHostRoutingRule(host: "Example.com.", targetIdentifier: targetIdentifier))
        let shortcut = try #require(PickerShortcut("s"))
        let snapshot = BrowserSettingsSnapshot(
            browserOrder: ["com.example.browser"],
            pickerShortcuts: ["com.example.browser": shortcut],
            exactHostRoutingRules: [rule]
        )
        let data = try snapshot.encodedData()
        #expect(data.last == 0x0A)
        let json = try #require(String(data: data, encoding: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(Set(object.keys) == Set(["version", "order", "shortcuts", "routingRules"]))
        let encodedRule = try #require((object["routingRules"] as? [[String: Any]])?.first)
        #expect(Set(encodedRule.keys) == Set(["matchHost", "targetIdentifier"]))
        #expect(encodedRule["targetIdentifier"] as? String == targetIdentifier)
        #expect(json.contains("\"version\" : 1"))
        #expect(json.contains("\"order\" : ["))
        #expect(json.contains("\"shortcuts\" : {"))
        #expect(json.contains("\"routingRules\" : ["))
        #expect(json.contains("\"matchHost\" : \"example.com\""))
        #expect(!json.contains("schemaVersion"))
        #expect(!json.contains("browserOrder"))
        #expect(!json.contains("pickerShortcuts"))
        #expect(!json.contains("exactHostRoutingRules"))
        #expect(!json.contains("\"host\""))
        let decoded = try JSONDecoder().decode(BrowserSettingsSnapshot.self, from: data)
        #expect(decoded == snapshot)
        #expect(decoded.exactHostRoutingRules.first?.targetIdentifier == targetIdentifier)
    }

    @Test("rejects missing, future, and malformed snapshots")
    func strictDecode() throws { // swiftlint:disable:this function_body_length
        #expect(throws: Error.self) {
            try JSONDecoder().decode(BrowserSettingsSnapshot.self, from: Data("{}".utf8))
        }
        #expect(throws: Error.self) {
            try JSONDecoder().decode(
                BrowserSettingsSnapshot.self,
                from: Data(
                    "{\"version\":2,\"order\":[],\"shortcuts\":{},\"routingRules\":[]}"
                        .utf8
                )
            )
        }
        #expect(throws: Error.self) {
            let invalidWhitespaceHost = Data(
                """
                {"version":1,"order":[],"shortcuts":{},
                "routingRules":[{"matchHost":" \t ","targetIdentifier":"x"}]}
                """
                .utf8
            )
            // The model rejects nonempty input once trimming leaves no hostname.
            _ = try JSONDecoder().decode(BrowserSettingsSnapshot.self, from: invalidWhitespaceHost)
        }
        #expect(throws: Error.self) {
            let missingMatchHost = Data(
                """
                {"version":1,"order":[],"shortcuts":{},
                "routingRules":[{"targetIdentifier":"x"}]}
                """
                .utf8
            )
            _ = try JSONDecoder().decode(BrowserSettingsSnapshot.self, from: missingMatchHost)
        }
        #expect(throws: Error.self) {
            let missingTargetIdentifier = Data(
                """
                {"version":1,"order":[],"shortcuts":{},
                "routingRules":[{"matchHost":"example.com"}]}
                """
                .utf8
            )
            _ = try JSONDecoder().decode(BrowserSettingsSnapshot.self, from: missingTargetIdentifier)
        }
        let unknownTopLevelKey = Data(
            """
            {"version":1,"order":[],"shortcuts":{},
            "routingRules":[],"futureKey":true}
            """
            .utf8
        )
        #expect(
            try JSONDecoder().decode(BrowserSettingsSnapshot.self, from: unknownTopLevelKey).browserOrder.isEmpty
        )
        #expect(throws: Error.self) {
            let malformed = Data(
                """
                {"version":1,"order":[],"shortcuts":{"x":"1"},"routingRules":[]}
                """.utf8
            )
            _ = try JSONDecoder().decode(
                BrowserSettingsSnapshot.self,
                from: malformed
            )
        }
        #expect(throws: Error.self) {
            let legacy = Data(
                """
                {"schemaVersion":1,"browserOrder":[],"pickerShortcuts":{},"exactHostRoutingRules":[]}
                """.utf8
            )
            _ = try JSONDecoder().decode(BrowserSettingsSnapshot.self, from: legacy)
        }
        #expect(throws: Error.self) {
            let unknownMatcher = Data(
                """
                {"version":1,"order":[],"shortcuts":{},
                "routingRules":[{"matchHost":"example.com","targetIdentifier":"x","matchHostSuffix":"example.org"}]}
                """.utf8
            )
            _ = try JSONDecoder().decode(BrowserSettingsSnapshot.self, from: unknownMatcher)
        }
        #expect(throws: Error.self) {
            let legacyRuleKey = Data(
                """
                {"version":1,"order":[],"shortcuts":{},
                "routingRules":[{"host":"example.com","targetIdentifier":"x"}]}
                """.utf8
            )
            _ = try JSONDecoder().decode(BrowserSettingsSnapshot.self, from: legacyRuleKey)
        }
    }

    @Test("writes and reads the fixed filename and reports missing")
    func fileRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("katabro-file-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let client = FilePreferencesClient(directoryURL: directory)
        #expect(client.read() == .missing)
        let snapshot = BrowserSettingsSnapshot(
            browserOrder: ["one"],
            pickerShortcuts: [:],
            exactHostRoutingRules: []
        )
        #expect(client.write(snapshot))
        guard case let .snapshot(decoded, _) = client.read() else {
            Issue.record("expected a decoded snapshot")
            return
        }
        #expect(decoded == snapshot)
        #expect(FileManager.default
            .fileExists(atPath: directory.appendingPathComponent(FilePreferencesClient.fileName).path))
    }

    @Test("rejects oversized, symlinked, and non-regular items")
    func rejectsUnsafeItems() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("katabro-file-safety-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent(FilePreferencesClient.fileName)
        try Data(repeating: 0x20, count: FilePreferencesClient.maximumFileSize + 1).write(to: file)
        #expect(clientResult(for: directory) == .invalid)

        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        #expect(clientResult(for: directory) == .invalid)

        try FileManager.default.removeItem(at: file)
        let target = directory.appendingPathComponent("target.json")
        try Data("{}".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: target)
        #expect(clientResult(for: directory) == .invalid)

        try FileManager.default.removeItem(at: file)
        let snapshot = BrowserSettingsSnapshot(
            browserOrder: ["fictional.browser"],
            pickerShortcuts: [:],
            exactHostRoutingRules: []
        )
        var padded = try snapshot.encodedData()
        padded.removeLast()
        padded.append(Data(repeating: 0x20, count: FilePreferencesClient.maximumFileSize - padded.count - 1))
        padded.append(0x0A)
        #expect(padded.count == FilePreferencesClient.maximumFileSize)
        try padded.write(to: file)
        guard case .snapshot = clientResult(for: directory) else {
            Issue.record("a valid snapshot padded to exactly 1 MiB should be accepted")
            return
        }
        padded.append(0x20)
        try padded.write(to: file)
        #expect(clientResult(for: directory) == .invalid)
    }

    @Test("monitors replacement, deletion, recreation, debounce, and self events")
    func monitorsRecoveryAndSuppression() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent(FilePreferencesClient.fileName)
        let first = BrowserSettingsSnapshot(browserOrder: ["one"], pickerShortcuts: [:], exactHostRoutingRules: [])
        let second = BrowserSettingsSnapshot(browserOrder: ["two"], pickerShortcuts: [:], exactHostRoutingRules: [])
        try first.encodedData().write(to: file)
        let client = FilePreferencesClient(directoryURL: directory)
        var events: [FilePreferencesClient.Event] = []
        #expect(client.start { events.append($0) })
        try await waitForEvent({ events }, { event in
            guard case let .snapshot(snapshot) = event else { return false }
            return snapshot == first
        })
        let countAfterStart = events.count

        #expect(client.write(first))
        try second.encodedData().write(to: file)
        try second.encodedData().write(to: file)
        try await waitForEvent({ events }, { event in
            if case let .snapshot(snapshot) = event {
                return snapshot == second
            }
            return false
        })
        #expect(events.count <= countAfterStart + 2)

        try FileManager.default.removeItem(at: file)
        try await waitForEvent({ events }, {
            if case .missing = $0 {
                return true
            }; return false
        })
        try first.encodedData().write(to: file)
        try await waitForEvent({ events }, { event in
            if case let .snapshot(snapshot) = event {
                return snapshot == first
            }
            return false
        })
        client.stop()
        #expect(client.start { events.append($0) })
        client.stop()
    }

    @Test("refreshes a stale bookmark before starting")
    func refreshesStaleBookmark() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("katabro-bookmark-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = BrowserSettingsSnapshot(browserOrder: [], pickerShortcuts: [:], exactHostRoutingRules: [])
        try snapshot.encodedData().write(to: directory.appendingPathComponent(FilePreferencesClient.fileName))
        var resolvedData: Data?
        let client = FilePreferencesClient(
            bookmarkData: Data("old".utf8),
            bookmarkResolver: { _ in (directory, true) },
            bookmarkMaker: { _ in
                let refreshed = Data("new".utf8)
                resolvedData = refreshed
                return refreshed
            }
        )
        let resolved = try client.resolveBookmark()
        #expect(resolved.refreshedBookmark == Data("new".utf8))
        #expect(resolvedData == Data("new".utf8))
        #expect(try client.bookmarkDataForDirectory() == Data("new".utf8))
        #expect(client.read() != .unavailable)
    }

    @Test("reuses a restored bookmark without recreating it before access starts")
    func reusesRestoredBookmark() throws {
        let storedBookmark = Data("stored".utf8)
        var bookmarkMakerCalls = 0
        let client = FilePreferencesClient(
            bookmarkData: storedBookmark,
            bookmarkResolver: { _ in
                (URL(fileURLWithPath: "/fixture/Documents", isDirectory: true), false)
            },
            bookmarkMaker: { _ in
                bookmarkMakerCalls += 1
                return Data("unexpected".utf8)
            }
        )

        _ = try client.resolveBookmark()

        #expect(try client.bookmarkDataForDirectory() == storedBookmark)
        #expect(bookmarkMakerCalls == 0)
    }

    @Test("abbreviates the home directory in the displayed location")
    func abbreviatedDisplayLocation() throws {
        let account = try #require(getpwuid(getuid()))
        let accountHome = URL(
            fileURLWithPath: String(cString: account.pointee.pw_dir),
            isDirectory: true
        )
        let directory = accountHome
            .appendingPathComponent("Documents", isDirectory: true)
        let client = FilePreferencesClient(directoryURL: directory)

        #expect(client.displayName == "Documents")
        #expect(client.displayLocation == "~/Documents")
    }

    @Test("does not abbreviate a sibling of the home directory")
    func doesNotAbbreviateHomeSibling() throws {
        let account = try #require(getpwuid(getuid()))
        let homePath = String(cString: account.pointee.pw_dir)
        let directory = URL(fileURLWithPath: homePath + "-shared/Documents", isDirectory: true)
        let client = FilePreferencesClient(directoryURL: directory)

        #expect(client.displayLocation == homePath + "-shared/Documents")
    }

    @Test("suppresses accepted bytes and reports later external bytes")
    func selfEventSuppression() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("katabro-file-events-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = FilePreferencesClient(directoryURL: directory)
        let first = BrowserSettingsSnapshot(browserOrder: ["one"], pickerShortcuts: [:], exactHostRoutingRules: [])
        let second = BrowserSettingsSnapshot(browserOrder: ["two"], pickerShortcuts: [:], exactHostRoutingRules: [])
        var events: [FilePreferencesClient.Event] = []
        try first.encodedData().write(to: directory.appendingPathComponent(FilePreferencesClient.fileName))
        #expect(client.start { events.append($0) })
        #expect(client.write(first))
        client.refresh()
        #expect(events.count == 1)
        try second.encodedData().write(to: directory.appendingPathComponent(FilePreferencesClient.fileName))
        client.refresh()
        #expect(events.count == 2)
        #expect(events.last.map {
            guard case let .snapshot(snapshot) = $0 else { return false }
            return snapshot == second
        } == true)
        client.stop()
        client.stop()
        #expect(client.start { events.append($0) })
    }

    @Test("retries unavailable reads exactly twice and recovers")
    func retriesAndRecovers() async throws {
        let snapshot = BrowserSettingsSnapshot(
            browserOrder: ["recovered"],
            pickerShortcuts: [:],
            exactHostRoutingRules: []
        )
        var reads = 0
        var events: [FilePreferencesClient.Event] = []
        let recoveringRead: @MainActor () -> FilePreferencesClient.ReadResult = {
            reads += 1
            return reads < 3
                ? .unavailable
                : .snapshot(snapshot, bytes: Data("recovered".utf8))
        }
        let client = FilePreferencesClient(injectedRead: recoveringRead)
        #expect(client.start { events.append($0) })
        try await waitForEvent({ events }, { event in
            guard case let .snapshot(value) = event else { return false }
            return value == snapshot
        })
        #expect(reads == 3)
    }

    @Test("reports unavailable after exactly two transient rereads")
    func retriesExhaust() async throws {
        var reads = 0
        var events: [FilePreferencesClient.Event] = []
        let exhaustingRead: @MainActor () -> FilePreferencesClient.ReadResult = {
            reads += 1
            return .unavailable
        }
        let client = FilePreferencesClient(injectedRead: exhaustingRead)
        #expect(client.start { events.append($0) })
        try await waitForEvent({ events }, { event in
            if case .unavailable = event {
                return true
            }
            return false
        })
        #expect(reads == 3)
    }

    @Test("classifies injected permission, write, and coordination failures")
    func injectedFailures() throws {
        let snapshot = BrowserSettingsSnapshot(browserOrder: [], pickerShortcuts: [:], exactHostRoutingRules: [])
        let unavailableRead: @MainActor () -> FilePreferencesClient.ReadResult = { .unavailable }
        let permissionClient = FilePreferencesClient(injectedRead: unavailableRead)
        #expect(permissionClient.read() == .unavailable)

        let rejectedWrite: @MainActor (BrowserSettingsSnapshot) -> Bool = { _ in false }
        let writeClient = FilePreferencesClient(injectedWrite: rejectedWrite)
        #expect(!writeClient.write(snapshot))

        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try snapshot.encodedData().write(to: directory.appendingPathComponent(FilePreferencesClient.fileName))
        let rejectedCoordination: @MainActor (URL, @escaping (URL) -> Void) -> Bool = { _, _ in false }
        let coordinationClient = FilePreferencesClient(
            directoryURL: directory,
            injectedReadCoordination: rejectedCoordination
        )
        #expect(coordinationClient.read() == .unavailable)
    }

    @Test("balances successful security-scoped starts across stop and restart")
    func balancesSecurityScope() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let starts = OSAllocatedUnfairLock(uncheckedState: 0)
        let stops = OSAllocatedUnfairLock(uncheckedState: 0)
        let client = FilePreferencesClient(
            directoryURL: directory,
            injectedRead: { .missing },
            startAccessing: { _ in starts.withLockUnchecked { $0 += 1 }; return true },
            stopAccessing: { _ in stops.withLockUnchecked { $0 += 1 } }
        )
        let firstStarted = client.start(onEvent: { _ in }, refreshImmediately: false)
        #expect(firstStarted)
        client.stop()
        let secondStarted = client.start(onEvent: { _ in }, refreshImmediately: false)
        #expect(secondStarted)
        client.stop()
        #expect(starts.withLockUnchecked { $0 } == 2)
        #expect(stops.withLockUnchecked { $0 } == 2)
    }

    @Test("does not stop a failed security-scoped start and balances deinit")
    func securityScopeFailureAndDeinit() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let starts = OSAllocatedUnfairLock(uncheckedState: 0)
        let stops = OSAllocatedUnfairLock(uncheckedState: 0)
        do {
            let failed = FilePreferencesClient(
                directoryURL: directory,
                bookmarkData: Data("bookmark".utf8),
                startAccessing: { _ in starts.withLockUnchecked { $0 += 1 }; return false },
                stopAccessing: { _ in stops.withLockUnchecked { $0 += 1 } }
            )
            let failedToStart = failed.start(onEvent: { _ in }, refreshImmediately: false)
            #expect(!failedToStart)
        }
        #expect(starts.withLockUnchecked { $0 } == 1)
        #expect(stops.withLockUnchecked { $0 } == 0)
        do {
            let active = FilePreferencesClient(
                directoryURL: directory,
                injectedRead: { .missing },
                startAccessing: { _ in starts.withLockUnchecked { $0 += 1 }; return true },
                stopAccessing: { _ in stops.withLockUnchecked { $0 += 1 } }
            )
            let activeStarted = active.start(onEvent: { _ in }, refreshImmediately: false)
            #expect(activeStarted)
        }
        #expect(stops.withLockUnchecked { $0 } == 1)
    }

    private func clientResult(for directory: URL) -> FilePreferencesClient.ReadResult {
        FilePreferencesClient(directoryURL: directory).read()
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("katabro-file-monitor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func waitForEvent(
        _ events: @escaping @MainActor () -> [FilePreferencesClient.Event],
        _ predicate: @escaping (FilePreferencesClient.Event) -> Bool
    ) async throws {
        for _ in 0 ..< 20 {
            if events().contains(where: predicate) {
                return
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        throw EventTimeout()
    }

    private struct EventTimeout: Error {}
}
