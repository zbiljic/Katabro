import AppKit
@testable import Katabro
import KatabroCore

@MainActor
final class SuspendedBrowserLauncher: BrowserLaunching {
    private var continuation: CheckedContinuation<Void, Never>?

    private(set) var requestCount = 0

    func open(
        _: IncomingURL,
        with _: BrowserLaunchTarget
    ) async throws {
        requestCount += 1
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitForRequest() async {
        while continuation == nil {
            await Task.yield()
        }
    }

    func succeed() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
final class BrowserPickerPresentationFake: BrowserPickerPresenting {
    var delegate: (any NSWindowDelegate)?

    private(set) var isClosed = false
    private(set) var isPresented = false

    func close() {
        isClosed = true
    }

    func presentNearPointer() {
        isPresented = true
    }
}

@MainActor
final class RoutingErrorPresenterFake: RoutingErrorPresenting {
    private(set) var presentedErrors: [String] = []

    func present(
        _ error: any Error
    ) {
        presentedErrors.append(
            String(describing: error)
        )
    }
}

@MainActor
final class CancellationRacingDiscovery: BrowserDiscovering {
    private let browsers: [BrowserApplication]
    private var firstContinuation: CheckedContinuation<[BrowserApplication], Error>?

    private(set) var destinations: [IncomingURL] = []

    init(
        browsers: [BrowserApplication]
    ) {
        self.browsers = browsers
    }

    func browsers(
        for destination: IncomingURL
    ) async throws -> [BrowserApplication] {
        destinations.append(destination)

        guard destinations.count == 1 else {
            return browsers
        }

        return try await withCheckedThrowingContinuation { continuation in
            firstContinuation = continuation
        }
    }

    func waitForFirstRequest() async {
        while firstContinuation == nil {
            await Task.yield()
        }
    }

    func failFirstRequest() {
        firstContinuation?.resume(
            throwing: BrowserPickerCoordinatorTests.TestError.expected
        )
        firstContinuation = nil
    }
}

@MainActor
final class BrowserDiscoveryFake: BrowserDiscovering {
    private let browsers: [BrowserApplication]
    private let error: Error?

    private(set) var destinations: [IncomingURL] = []

    init(
        browsers: [BrowserApplication] = [],
        error: Error? = nil
    ) {
        self.browsers = browsers
        self.error = error
    }

    func browsers(
        for destination: IncomingURL
    ) async throws -> [BrowserApplication] {
        destinations.append(destination)

        if let error {
            throw error
        }

        return browsers
    }
}

@MainActor
final class BrowserLauncherFake: BrowserLaunching {
    struct OpenedRequest: Equatable {
        let destination: IncomingURL
        let browser: BrowserApplication
    }

    private let error: Error?

    private(set) var openedRequests: [OpenedRequest] = []

    init(
        error: Error? = nil
    ) {
        self.error = error
    }

    func open(
        _ destination: IncomingURL,
        with target: BrowserLaunchTarget
    ) async throws {
        openedRequests.append(
            OpenedRequest(
                destination: destination,
                browser: target.browser
            )
        )

        if let error {
            throw error
        }
    }
}
