import Foundation

public struct IncomingURL: Hashable, Sendable {
    public enum Scheme: String, CaseIterable, Sendable {
        case http
        case https
    }

    public enum ValidationError: Error, Equatable, Sendable {
        case empty
        case malformed
        case relative
        case unsupportedScheme(String)
        case missingHost
    }

    public let url: URL
    public let scheme: Scheme

    public init(_ rawValue: String) throws(ValidationError) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else {
            throw .empty
        }

        guard let url = URL(string: value) else {
            throw .malformed
        }

        try self.init(url)
    }

    public init(_ url: URL) throws(ValidationError) {
        guard url.baseURL == nil else {
            throw .relative
        }

        guard let rawScheme = url.scheme?.lowercased() else {
            throw .relative
        }

        guard let scheme = Scheme(rawValue: rawScheme) else {
            throw .unsupportedScheme(rawScheme)
        }

        guard let host = url.host(), !host.isEmpty else {
            throw .missingHost
        }

        self.url = url
        self.scheme = scheme
    }
}

extension IncomingURL.ValidationError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            "The URL is empty."
        case .malformed:
            "The URL is malformed."
        case .relative:
            "The URL must be absolute."
        case let .unsupportedScheme(scheme):
            "The URL scheme '\(scheme)' is not supported."
        case .missingHost:
            "The URL must include a host."
        }
    }
}
