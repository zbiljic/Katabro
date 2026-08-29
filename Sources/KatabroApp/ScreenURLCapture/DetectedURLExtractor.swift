import Foundation
import KatabroCore

enum DetectedURLExtractor {
    static func extract(
        from recognizedStrings: [String]
    ) -> [DetectedURL] {
        guard
            let detector = try? NSDataDetector(
                types: NSTextCheckingResult.CheckingType.link.rawValue
            )
        else {
            return []
        }

        var seen = Set<String>()
        var detected: [DetectedURL] = []

        for string in recognizedStrings {
            let range = NSRange(string.startIndex..., in: string)
            for match in detector.matches(in: string, range: range) {
                guard
                    let url = match.url,
                    let matchedRange = Range(match.range, in: string),
                    let destination = try? IncomingURL(url),
                    destination.scheme == .http || destination.scheme == .https,
                    seen.insert(destination.url.absoluteString).inserted
                else {
                    continue
                }
                detected.append(
                    DetectedURL(
                        destination: destination,
                        recognizedString: String(string[matchedRange])
                    )
                )
            }
        }
        return detected
    }
}
