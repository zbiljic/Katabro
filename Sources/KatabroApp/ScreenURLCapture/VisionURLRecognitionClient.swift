@preconcurrency import CoreGraphics
import Foundation
@preconcurrency import Vision

enum VisionURLRecognitionError: Error, Sendable {
    case unavailable
    case recognitionFailed
}

@MainActor
struct VisionURLRecognitionClient {
    let isAvailable: () -> Bool
    let recognizeURLs: (CGImage) async throws -> [DetectedURL]

    static let live = Self(
        isAvailable: {
            guard VNRecognizeTextRequest.supportedRevisions.contains(3) else { return false }
            guard
                let languages = try? VNRecognizeTextRequest.supportedRecognitionLanguages(
                    for: .accurate,
                    revision: 3
                ) else { return false }
            return !languages.isEmpty
        },
        recognizeURLs: { image in
            try await withThrowingTaskGroup(of: [DetectedURL].self) { group in
                group.addTask(priority: .userInitiated) {
                    try Task.checkCancellation()
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true
                    request.automaticallyDetectsLanguage = true
                    request.revision = 3
                    do {
                        try VNImageRequestHandler(cgImage: image).perform([request])
                    } catch {
                        throw VisionURLRecognitionError.recognitionFailed
                    }
                    try Task.checkCancellation()
                    let observations = request.results ?? []
                    let strings = observations.compactMap { $0.topCandidates(1).first?.string }
                    return await MainActor.run {
                        DetectedURLExtractor.extract(from: strings)
                    }
                }
                defer { group.cancelAll() }
                return try await group.next() ?? []
            }
        }
    )

    static let unavailable = Self(
        isAvailable: { false },
        recognizeURLs: { _ in throw VisionURLRecognitionError.unavailable }
    )
}
