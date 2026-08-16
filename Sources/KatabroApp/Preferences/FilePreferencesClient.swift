import Darwin
import Foundation

@MainActor
final class FilePreferencesClient { // swiftlint:disable:this type_body_length
    enum Event: Equatable, Sendable {
        case snapshot(BrowserSettingsSnapshot)
        case missing
        case invalid
        case unavailable
    }

    enum ReadResult: Equatable, Sendable {
        case snapshot(BrowserSettingsSnapshot, bytes: Data)
        case missing
        case invalid
        case unavailable
    }

    static let fileName = "katabro-settings.json"
    static let maximumFileSize = 1_048_576

    var displayName: String {
        displayNameOverride ?? directoryURL?.lastPathComponent ?? "Folder"
    }

    var displayLocation: String {
        if let displayLocationOverride {
            return displayLocationOverride
        }
        guard let directoryURL else { return displayName }
        return Self.abbreviatedAccountPath(directoryURL.path)
    }

    private static func abbreviatedAccountPath(_ path: String) -> String {
        guard let account = getpwuid(getuid()) else { return path }
        let homePath = String(cString: account.pointee.pw_dir)
        guard path != homePath else { return "~" }
        let homePrefix = homePath + "/"
        guard path.hasPrefix(homePrefix) else { return path }
        return "~/" + String(path.dropFirst(homePrefix.count))
    }

    private(set) var directoryURL: URL?
    private let displayNameOverride: String?
    private let displayLocationOverride: String?
    private var bookmarkData: Data?
    private let bookmarkResolver: @MainActor (Data) throws -> (URL, Bool)
    private let bookmarkMaker: @MainActor (URL) throws -> Data
    private let fileCoordinator: NSFileCoordinator
    private let injectedReadCoordination: (@MainActor (URL, @escaping (URL) -> Void) -> Bool)?
    private let injectedRead: (@MainActor () -> ReadResult)?
    private let injectedWrite: (@MainActor (BrowserSettingsSnapshot) -> Bool)?
    private let startAccessing: @Sendable (URL) -> Bool
    private let stopAccessing: @Sendable (URL) -> Void
    private var monitor: DispatchSourceFileSystemObject?
    private var monitorDescriptor: Int32 = -1
    private var eventHandler: (@MainActor (Event) -> Void)?
    private var lastAcceptedBytes: Data?
    private var accessIsActive = false
    private var refreshTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var rearmTask: Task<Void, Never>?

    init(
        directoryURL: URL? = nil,
        bookmarkData: Data? = nil,
        bookmarkResolver: @escaping @MainActor (Data) throws -> (URL, Bool) = { data in
            var stale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            return (url, stale)
        },
        bookmarkMaker: @escaping @MainActor (URL) throws -> Data = { url in
            try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        },
        fileCoordinator: NSFileCoordinator = NSFileCoordinator(),
        injectedReadCoordination: (@MainActor (URL, @escaping (URL) -> Void) -> Bool)? = nil,
        injectedRead: (@MainActor () -> ReadResult)? = nil,
        injectedWrite: (@MainActor (BrowserSettingsSnapshot) -> Bool)? = nil,
        displayName: String? = nil,
        displayLocation: String? = nil,
        startAccessing: @escaping @Sendable (URL) -> Bool = { url in
            url.startAccessingSecurityScopedResource()
        },
        stopAccessing: @escaping @Sendable (URL) -> Void = { url in
            url.stopAccessingSecurityScopedResource()
        }
    ) {
        self.directoryURL = directoryURL
        displayNameOverride = displayName
        displayLocationOverride = displayLocation
        self.bookmarkData = bookmarkData
        self.bookmarkResolver = bookmarkResolver
        self.bookmarkMaker = bookmarkMaker
        self.fileCoordinator = fileCoordinator
        self.injectedReadCoordination = injectedReadCoordination
        self.injectedRead = injectedRead
        self.injectedWrite = injectedWrite
        self.startAccessing = startAccessing
        self.stopAccessing = stopAccessing
    }

    deinit {
        refreshTask?.cancel()
        retryTask?.cancel()
        rearmTask?.cancel()
        if let monitor {
            self.monitor = nil
            monitorDescriptor = -1
            monitor.cancel()
        } else if monitorDescriptor >= 0 {
            close(monitorDescriptor)
        }
        if accessIsActive, let directoryURL {
            stopAccessing(directoryURL)
        }
    }

    func bookmarkDataForDirectory() throws -> Data? {
        if let bookmarkData {
            return bookmarkData
        }
        guard let directoryURL else { return nil }
        return try bookmarkMaker(directoryURL)
    }

    @discardableResult
    func resolveBookmark() throws -> (url: URL, refreshedBookmark: Data?) {
        guard let storedBookmarkData = bookmarkData else {
            guard let directoryURL else { throw CocoaError(.fileNoSuchFile) }
            return (directoryURL, nil)
        }
        let (url, stale) = try bookmarkResolver(storedBookmarkData)
        directoryURL = url
        let refreshedBookmark = try (stale ? bookmarkMaker(url) : nil)
        if let refreshedBookmark {
            bookmarkData = refreshedBookmark
        }
        return (url, refreshedBookmark)
    }

    func start(
        onEvent: @escaping @MainActor (Event) -> Void,
        refreshImmediately: Bool = true
    ) -> Bool {
        guard monitor == nil else { return true }
        guard let directoryURL else {
            guard injectedRead != nil else { return false }
            eventHandler = onEvent
            if refreshImmediately {
                refresh()
            }
            return true
        }
        eventHandler = onEvent
        let didStartAccessing = startAccessing(directoryURL)
        guard didStartAccessing || bookmarkData == nil else { return false }
        accessIsActive = didStartAccessing
        guard openMonitor() else {
            if accessIsActive {
                stopAccessing(directoryURL)
            }
            accessIsActive = false
            return false
        }
        if refreshImmediately {
            refresh()
        }
        return true
    }

    func setEventHandler(_ onEvent: @escaping @MainActor (Event) -> Void) {
        eventHandler = onEvent
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        retryTask?.cancel()
        retryTask = nil
        rearmTask?.cancel()
        rearmTask = nil
        guard monitor != nil || accessIsActive else {
            eventHandler = nil
            return
        }
        monitor?.cancel()
        monitor = nil
        monitorDescriptor = -1
        if accessIsActive {
            if let directoryURL {
                stopAccessing(directoryURL)
            }
            accessIsActive = false
        }
        eventHandler = nil
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            self?.refresh()
            self?.rearmIfDirectoryWasReplaced()
        }
    }

    private func scheduleRetry(attempt: Int = 1) {
        retryTask?.cancel()
        retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled, let self else { return }
            let result = read()
            if case .unavailable = result, attempt < 2 {
                scheduleRetry(attempt: attempt + 1)
            } else if case .unavailable = result {
                eventHandler?(.unavailable)
            } else {
                deliver(result)
            }
        }
    }

    private func openMonitor() -> Bool {
        guard let directoryURL else { return false }
        let descriptor = open(directoryURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return false }
        monitorDescriptor = descriptor
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .attrib, .extend, .link],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleRefresh()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        monitor = source
        source.resume()
        return true
    }

    private func rearmIfDirectoryWasReplaced() {
        guard let directoryURL, !FileManager.default.fileExists(atPath: directoryURL.path) else {
            return
        }
        monitor?.cancel()
        monitor = nil
        monitorDescriptor = -1
        rearmTask?.cancel()
        rearmTask = Task { @MainActor [weak self] in
            for _ in 0 ..< 20 {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, let self, let directoryURL = self.directoryURL else { return }
                guard monitor == nil else { return }
                guard FileManager.default.fileExists(atPath: directoryURL.path) else { continue }
                guard openMonitor() else { continue }
                refresh()
                return
            }
        }
    }

    func refresh() {
        deliver(read())
    }

    private func deliver(_ result: ReadResult) {
        switch result {
        case let .snapshot(snapshot, bytes):
            if bytes == lastAcceptedBytes {
                return
            }
            lastAcceptedBytes = bytes
            eventHandler?(.snapshot(snapshot))
        case .missing:
            lastAcceptedBytes = nil
            eventHandler?(.missing)
        case .invalid:
            lastAcceptedBytes = nil
            eventHandler?(.invalid)
        case .unavailable:
            lastAcceptedBytes = nil
            scheduleRetry()
        }
    }

    // File safety checks intentionally remain together so every read follows the
    // same all-or-nothing path.
    // swiftlint:disable:next cyclomatic_complexity
    func read() -> ReadResult { // swiftlint:disable:this function_body_length
        if let injectedRead {
            return injectedRead()
        }
        guard let fileURL else { return .unavailable }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .missing
        }
        var result: ReadResult = .unavailable
        let readItem: (URL) -> Void = { url in
            do {
                let resourceValues = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
                guard resourceValues.isSymbolicLink != true, resourceValues.isRegularFile == true else {
                    result = .invalid
                    return
                }
                let attributes: [FileAttributeKey: Any]
                do {
                    attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                } catch {
                    result = .unavailable
                    return
                }
                guard attributes[.type] as? FileAttributeType == .typeRegular else {
                    result = .invalid
                    return
                }
                guard
                    let size = attributes[.size] as? NSNumber,
                    size.intValue <= Self.maximumFileSize
                else {
                    result = .invalid
                    return
                }
                let data: Data
                do {
                    data = try Data(contentsOf: url, options: [.mappedIfSafe])
                } catch {
                    result = .unavailable
                    return
                }
                guard data.count <= Self.maximumFileSize else {
                    result = .invalid
                    return
                }
                do {
                    let snapshot = try JSONDecoder().decode(BrowserSettingsSnapshot.self, from: data)
                    result = .snapshot(snapshot, bytes: data)
                } catch {
                    result = .invalid
                }
            } catch {
                result = .unavailable
            }
        }
        var coordinationError: NSError?
        if let injectedReadCoordination {
            guard injectedReadCoordination(fileURL, readItem) else { return .unavailable }
        } else {
            fileCoordinator.coordinate(
                readingItemAt: fileURL,
                options: [],
                error: &coordinationError,
                byAccessor: readItem
            )
        }
        if coordinationError != nil {
            return .unavailable
        }
        return result
    }

    @discardableResult
    func write(_ snapshot: BrowserSettingsSnapshot) -> Bool {
        if let injectedWrite {
            return injectedWrite(snapshot)
        }
        guard let fileURL, let directoryURL else { return false }
        guard let data = try? snapshot.encodedData() else { return false }
        switch read() {
        case .missing, .snapshot:
            break
        case .invalid, .unavailable:
            return false
        }
        let temporaryURL = directoryURL.appendingPathComponent(".katabro-settings-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        do {
            try data.write(to: temporaryURL, options: .atomic)
        } catch {
            return false
        }
        var coordinationError: NSError?
        var didWrite = false
        if FileManager.default.fileExists(atPath: fileURL.path) {
            fileCoordinator.coordinate(
                writingItemAt: fileURL,
                options: .forReplacing,
                error: &coordinationError
            ) { url in
                do {
                    _ = try FileManager.default.replaceItemAt(
                        url,
                        withItemAt: temporaryURL,
                        backupItemName: nil,
                        options: .usingNewMetadataOnly
                    )
                    didWrite = true
                } catch {
                    didWrite = false
                }
            }
        } else {
            fileCoordinator.coordinate(
                writingItemAt: directoryURL,
                options: [],
                error: &coordinationError
            ) { _ in
                do {
                    try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
                    didWrite = true
                } catch {
                    didWrite = false
                }
            }
        }
        guard coordinationError == nil, didWrite else { return false }
        lastAcceptedBytes = data
        return true
    }

    private var fileURL: URL? {
        directoryURL?.appendingPathComponent(Self.fileName, isDirectory: false)
    }
}
