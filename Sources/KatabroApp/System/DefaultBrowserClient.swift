import AppKit
import CoreServices
import Observation

#if DEBUG
    @MainActor
    private final class DevelopmentDefaultBrowserState {
        var status: DefaultBrowserClient.Status

        init(
            status: DefaultBrowserClient.Status
        ) {
            self.status = status
        }
    }
#endif

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

                return Self.bundleIdentifier(
                    for: applicationURL
                ) {
                    LSCopyDefaultHandlerForURLScheme(
                        scheme as CFString
                    )?.takeRetainedValue() as String?
                }
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

    static func bundleIdentifier(
        for applicationURL: URL,
        fallbackHandler: () -> String?
    ) -> String? {
        Bundle(url: applicationURL)?.bundleIdentifier
            ?? fallbackHandler()
    }

    #if DEBUG
        static func development(
            status: Status,
            lastError: String? = nil
        ) -> DefaultBrowserClient {
            let state = DevelopmentDefaultBrowserState(
                status: status
            )
            let client = Self(
                appBundleIdentifier: AppMetadata.bundleIdentifier,
                currentHandler: { _ in
                    switch state.status {
                    case .current:
                        AppMetadata.bundleIdentifier
                    case .notCurrent:
                        "com.apple.Safari"
                    case .unavailable:
                        nil
                    }
                },
                requestHandler: { _ in
                    if let lastError {
                        throw DevelopmentUIError(
                            message: lastError
                        )
                    }

                    state.status = .current
                }
            )
            client.lastError = lastError
            return client
        }
    #endif

    func refresh() {
        refresh(
            clearsResolvedError: true
        )
    }

    private func refresh(
        clearsResolvedError: Bool
    ) {
        let previousStatus = status
        let identifiers = ["http", "https"].compactMap(currentHandler)

        guard identifiers.count == 2 else {
            status = .unavailable
            clearResolvedError(
                previousStatus: previousStatus,
                clearsResolvedError: clearsResolvedError
            )
            return
        }

        status = identifiers.allSatisfy { identifier in
            identifier.caseInsensitiveCompare(appBundleIdentifier) == .orderedSame
        } ? .current : .notCurrent
        clearResolvedError(
            previousStatus: previousStatus,
            clearsResolvedError: clearsResolvedError
        )
    }

    func requestDefaultBrowser() async {
        guard !isRequesting else {
            return
        }

        isRequesting = true
        lastError = nil

        defer {
            isRequesting = false
            refresh(
                clearsResolvedError: false
            )

            if status == .current {
                lastError = nil
            }
        }

        do {
            try await requestHandler("http")
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func clearResolvedError(
        previousStatus: Status,
        clearsResolvedError: Bool
    ) {
        guard
            clearsResolvedError,
            status == .current || status != previousStatus
        else {
            return
        }

        lastError = nil
    }
}
