import AppKit
import Observation

@MainActor
@Observable
final class DefaultBrowserClient {
    enum Status: Equatable, Sendable {
        case current
        case notCurrent
        case unavailable
    }

    typealias CurrentHandler = @MainActor (_ scheme: String) -> String?
    typealias RequestHandler = @MainActor (_ scheme: String) async throws -> Void

    @ObservationIgnored private let appBundleIdentifier: String
    @ObservationIgnored private let currentHandler: CurrentHandler
    @ObservationIgnored private let requestHandler: RequestHandler

    private(set) var isRequesting = false
    private(set) var lastError: String?
    private(set) var status = Status.unavailable

    var statusDescription: String {
        switch status {
        case .current:
            "Katabro is the default browser for web links."
        case .notCurrent:
            "Katabro is not the default browser for all web links."
        case .unavailable:
            "The current default browser could not be determined."
        }
    }

    init(
        appBundleIdentifier: String,
        currentHandler: @escaping CurrentHandler,
        requestHandler: @escaping RequestHandler
    ) {
        self.appBundleIdentifier = appBundleIdentifier
        self.currentHandler = currentHandler
        self.requestHandler = requestHandler
        refresh()
    }

    static func live(
        bundle: Bundle = .main,
        workspace: NSWorkspace = .shared
    ) -> DefaultBrowserClient {
        let appBundleIdentifier = bundle.bundleIdentifier ?? AppMetadata.bundleIdentifier
        let applicationURL = bundle.bundleURL

        return Self(
            appBundleIdentifier: appBundleIdentifier,
            currentHandler: { scheme in
                guard
                    let sampleURL = URL(string: "\(scheme)://example.com"),
                    let applicationURL = workspace.urlForApplication(
                        toOpen: sampleURL
                    )
                else {
                    return nil
                }

                return Bundle(
                    url: applicationURL
                )?.bundleIdentifier
            },
            requestHandler: { scheme in
                try await withCheckedThrowingContinuation { continuation in
                    workspace.setDefaultApplication(
                        at: applicationURL,
                        toOpenURLsWithScheme: scheme
                    ) { error in
                        if let error {
                            continuation.resume(
                                throwing: error
                            )
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }
        )
    }

    func refresh() {
        let identifiers = ["http", "https"].compactMap(currentHandler)

        guard identifiers.count == 2 else {
            status = .unavailable
            return
        }

        status = identifiers.allSatisfy { identifier in
            identifier.caseInsensitiveCompare(appBundleIdentifier) == .orderedSame
        } ? .current : .notCurrent
    }

    func requestDefaultBrowser() async {
        guard !isRequesting else {
            return
        }

        isRequesting = true
        lastError = nil

        defer {
            isRequesting = false
            refresh()
        }

        do {
            for scheme in ["http", "https"] {
                try await requestHandler(scheme)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
