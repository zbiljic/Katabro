import Foundation

public struct IncomingURL: Hashable, Sendable {
    public enum Scheme: String, CaseIterable, Sendable {
        case file
        case http
        case https
    }

    public enum ValidationError: Error, Equatable, Sendable {
        case empty
        case malformed
        case relative
        case unsupportedScheme(String)
        case missingHost
        case invalidFilePath
        case invalidFileAuthority
        case remoteFileAuthority(String)
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

        switch scheme {
        case .file:
            try Self.validateFileURL(url)
        case .http, .https:
            guard let host = url.host(), !host.isEmpty else {
                throw .missingHost
            }
        }

        self.url = url
        self.scheme = scheme
    }

    private static func validateFileURL(
        _ url: URL
    ) throws(ValidationError) {
        guard url.isFileURL else {
            throw .invalidFilePath
        }

        if let host = url.host(), !host.isEmpty, host.lowercased() != "localhost" {
            throw .remoteFileAuthority(host)
        }

        guard
            url.user() == nil,
            url.password == nil,
            url.port == nil
        else {
            throw .invalidFileAuthority
        }

        let path = url.path
        guard !path.isEmpty else {
            throw .invalidFilePath
        }

        guard
            path.hasPrefix("/"),
            !path.hasPrefix("//"),
            path != "/"
        else {
            if !path.hasPrefix("/") {
                throw .relative
            }
            throw .invalidFilePath
        }
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
        case .invalidFilePath:
            "The file URL must include an absolute, non-root local path."
        case .invalidFileAuthority:
            "The file URL authority is not supported."
        case let .remoteFileAuthority(host):
            "The file URL authority '\(host)' is not local."
        }
    }
}

extension IncomingURL.ValidationError: LocalizedError {
    public var errorDescription: String? {
        description
    }
}
