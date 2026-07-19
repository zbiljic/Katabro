import Foundation

public struct CommandLineRequest: Equatable, Sendable {
    public enum ParsingError: Error, Equatable, Sendable {
        case incorrectArgumentCount(Int)
        case invalidURL(IncomingURL.ValidationError)
    }

    public let destination: IncomingURL

    public init(
        arguments: [String]
    ) throws(ParsingError) {
        guard arguments.count == 1 else {
            throw .incorrectArgumentCount(arguments.count)
        }

        do {
            destination = try IncomingURL(arguments[0])
        } catch {
            throw .invalidURL(error)
        }
    }

    public func transportURL() throws(KatabroURL.CodingError) -> URL {
        try KatabroURL.encode(destination)
    }
}

extension CommandLineRequest.ParsingError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .incorrectArgumentCount(count):
            "Expected one URL argument, received \(count)."
        case let .invalidURL(error):
            error.description
        }
    }
}
