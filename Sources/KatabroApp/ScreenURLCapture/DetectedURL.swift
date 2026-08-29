import KatabroCore

struct DetectedURL: Identifiable, Equatable, Hashable, Sendable {
    let destination: IncomingURL
    let recognizedString: String

    var id: String {
        destination.url.absoluteString
    }

    init(
        destination: IncomingURL,
        recognizedString: String? = nil
    ) {
        self.destination = destination
        self.recognizedString = recognizedString ?? destination.url.absoluteString
    }
}
