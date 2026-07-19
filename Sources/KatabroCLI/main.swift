import AppKit
import Darwin
import Foundation
import KatabroCore

func writeError(
    _ message: String
) {
    FileHandle.standardError.write(
        Data("\(message)\n".utf8)
    )
}

let arguments = Array(
    CommandLine.arguments.dropFirst()
)

do {
    let request = try CommandLineRequest(
        arguments: arguments
    )
    let transportURL = try request.transportURL()

    guard NSWorkspace.shared.open(transportURL) else {
        writeError("Katabro could not open the routing request.")
        exit(EXIT_FAILURE)
    }
} catch let error as CommandLineRequest.ParsingError {
    writeError("katabro: \(error.description)")
    writeError("Usage: katabro <http-or-https-url>")
    exit(EXIT_FAILURE)
} catch {
    writeError("katabro: \(error)")
    exit(EXIT_FAILURE)
}
