import Foundation

public enum KatabroURL {
    public enum CodingError: Error, Equatable, Sendable {
        case wrongScheme(String?)
        case unsupportedAction(String?)
        case missingDestination
        case duplicateDestination
        case invalidDestination(IncomingURL.ValidationError)
        case encodingFailed
    }

    public static func decode(
        _ url: URL
    ) throws(CodingError) -> IncomingURL {
        guard url.scheme?.lowercased() == KatabroCore.transportScheme else {
            throw .wrongScheme(url.scheme)
        }

        guard url.host()?.lowercased() == "open" else {
            throw .unsupportedAction(url.host())
        }

        guard
            let components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )
        else {
            throw .missingDestination
        }

        let destinationItems = (components.queryItems ?? [])
            .filter { $0.name == "url" }

        guard destinationItems.count <= 1 else {
            throw .duplicateDestination
        }

        guard
            let destination = destinationItems.first?.value,
            !destination.isEmpty
        else {
            throw .missingDestination
        }

        do {
            return try IncomingURL(destination)
        } catch {
            throw .invalidDestination(error)
        }
    }

    public static func encode(
        _ destination: IncomingURL
    ) throws(CodingError) -> URL {
        var components = URLComponents()
        components.scheme = KatabroCore.transportScheme
        components.host = "open"
        components.queryItems = [
            URLQueryItem(
                name: "url",
                value: destination.url.absoluteString
            ),
        ]

        guard let url = components.url else {
            throw .encodingFailed
        }

        return url
    }
}

extension KatabroURL.CodingError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .wrongScheme(scheme):
            "Expected a katabro URL, received '\(scheme ?? "none")'."
        case let .unsupportedAction(action):
            "The Katabro action '\(action ?? "none")' is not supported."
        case .missingDestination:
            "The Katabro URL is missing its destination."
        case .duplicateDestination:
            "The Katabro URL contains more than one destination."
        case let .invalidDestination(error):
            error.description
        case .encodingFailed:
            "The Katabro URL could not be encoded."
        }
    }
}

extension KatabroURL.CodingError: LocalizedError {
    public var errorDescription: String? {
        description
    }
}
