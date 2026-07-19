import Observation
import ServiceManagement

@MainActor
@Observable
final class LoginItemClient {
    enum Status: Equatable, Sendable {
        case disabled
        case enabled
        case requiresApproval
        case unavailable
    }

    typealias StatusProvider = @MainActor () -> Status
    typealias UpdateHandler = @MainActor (_ enabled: Bool) throws -> Void

    @ObservationIgnored private let statusProvider: StatusProvider
    @ObservationIgnored private let updateHandler: UpdateHandler

    private(set) var lastError: String?
    private(set) var status = Status.unavailable

    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    var statusDescription: String {
        switch status {
        case .disabled:
            "Katabro will not open automatically when you log in."
        case .enabled:
            "Katabro will open automatically when you log in."
        case .requiresApproval:
            "Allow Katabro in System Settings → General → Login Items."
        case .unavailable:
            "Login-item status is unavailable for this build."
        }
    }

    init(
        statusProvider: @escaping StatusProvider,
        updateHandler: @escaping UpdateHandler
    ) {
        self.statusProvider = statusProvider
        self.updateHandler = updateHandler
        refresh()
    }

    static func live(
        service: SMAppService = .mainApp
    ) -> LoginItemClient {
        Self(
            statusProvider: {
                switch service.status {
                case .notRegistered:
                    .disabled
                case .enabled:
                    .enabled
                case .requiresApproval:
                    .requiresApproval
                case .notFound:
                    .unavailable
                @unknown default:
                    .unavailable
                }
            },
            updateHandler: { enabled in
                if enabled {
                    try service.register()
                } else {
                    try service.unregister()
                }
            }
        )
    }

    func refresh() {
        refresh(
            clearsResolvedError: true
        )
    }

    private func refresh(
        clearsResolvedError: Bool
    ) {
        let previousStatus = status
        status = statusProvider()

        let didResolveError = clearsResolvedError && (
            status == .enabled || status != previousStatus
        )

        if didResolveError {
            lastError = nil
        }
    }

    func update(
        enabled: Bool
    ) {
        lastError = nil

        do {
            try updateHandler(enabled)
        } catch {
            lastError = error.localizedDescription
        }

        refresh(
            clearsResolvedError: false
        )
    }
}
