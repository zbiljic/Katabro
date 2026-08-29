import Foundation
import KatabroCore

struct RoutingDecisionLogEntry: Equatable, Identifiable, Sendable {
    enum DestinationKind: Equatable, Sendable {
        case web
        case localFile
    }

    enum WebScheme: String, Equatable, Sendable {
        case http
        case https
    }

    enum Decision: Equatable, Sendable {
        // swiftlint:disable:next nesting
        enum BrowserPickerReason: Equatable, Sendable {
            case noMatchingRule
            case savedTargetUnavailable

            var summary: String {
                switch self {
                case .noMatchingRule:
                    "No matching rule"
                case .savedTargetUnavailable:
                    "Saved target unavailable"
                }
            }
        }

        case evaluating
        case exactHostRule(targetDisplayLabel: String)
        case browserPicker(reason: BrowserPickerReason)

        var summary: String {
            switch self {
            case .evaluating:
                "Evaluating"
            case .exactHostRule:
                "Exact-host rule"
            case let .browserPicker(reason):
                "Browser picker — \(reason.summary)"
            }
        }

        var targetDisplayLabel: String? {
            guard case let .exactHostRule(targetDisplayLabel) = self else {
                return nil
            }
            return targetDisplayLabel
        }
    }

    enum Result: Equatable, Sendable {
        case pending
        case opened(
            targetIdentifier: String,
            targetDisplayLabel: String
        )
        case copiedLink
        case cancelled
        case failed(Failure)

        var summary: String {
            switch self {
            case .pending:
                "Pending"
            case .opened:
                "Opened"
            case .copiedLink:
                "Copied link"
            case .cancelled:
                "Cancelled"
            case let .failed(failure):
                failure.summary
            }
        }

        var targetDisplayLabel: String? {
            guard case let .opened(_, targetDisplayLabel) = self else {
                return nil
            }
            return targetDisplayLabel
        }
    }

    enum Failure: Equatable, Sendable {
        case routing
        case copyingLink
        case openingTarget

        var summary: String {
            switch self {
            case .routing:
                "Routing failed"
            case .copyingLink:
                "Couldn’t copy link"
            case .openingTarget:
                "Couldn’t open target"
            }
        }
    }

    struct RuleCandidate: Equatable, Sendable {
        let destination: IncomingURL
        let host: String
        let targetIdentifier: String
        let targetDisplayLabel: String
    }

    let id: UUID
    let receivedAt: Date
    let destinationKind: DestinationKind
    let webScheme: WebScheme?
    let normalizedHost: String?
    let source: RoutingRequest.Source
    var decision: Decision
    var result: Result

    init(
        request: RoutingRequest,
        receivedAt: Date
    ) {
        id = request.id
        self.receivedAt = receivedAt
        source = request.source
        decision = .evaluating
        result = .pending

        switch request.destination.scheme {
        case .file:
            destinationKind = .localFile
            webScheme = nil
            normalizedHost = nil
        case .http, .https:
            destinationKind = .web
            webScheme = WebScheme(
                rawValue: request.destination.scheme.rawValue
            )
            normalizedHost = request.destination.url.host().flatMap(
                ExactHostRoutingRule.normalizedHost
            )
        }
    }

    var destinationDisplayName: String {
        switch destinationKind {
        case .web:
            normalizedHost ?? "Unknown Host"
        case .localFile:
            "Local File"
        }
    }

    var sourceDisplayName: String {
        switch source {
        case .system:
            "System"
        case .commandLine:
            "Command Line"
        case .customURL:
            "Custom URL"
        case .screenCapture:
            "Screen Capture"
        }
    }

    var targetDisplayLabel: String? {
        result.targetDisplayLabel ?? decision.targetDisplayLabel
    }

    var ruleCandidate: RuleCandidate? {
        guard
            destinationKind == .web,
            let webScheme,
            let normalizedHost,
            case let .opened(
                targetIdentifier,
                targetDisplayLabel
            ) = result
        else {
            return nil
        }

        var components = URLComponents()
        components.scheme = webScheme.rawValue
        components.host = normalizedHost

        guard
            let sanitizedURL = components.url,
            let destination = try? IncomingURL(sanitizedURL)
        else {
            return nil
        }

        return RuleCandidate(
            destination: destination,
            host: normalizedHost,
            targetIdentifier: targetIdentifier,
            targetDisplayLabel: targetDisplayLabel
        )
    }
}
