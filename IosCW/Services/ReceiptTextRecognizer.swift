import UIKit
import Vision

protocol TextRecognizing {
    func recognize(_ image: UIImage) async throws -> [RecognizedLine]
}

enum RecognitionError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage: "That image couldn't be read."
        }
    }
}

final class VisionTextRecognizer: TextRecognizing {
    func recognize(_ image: UIImage) async throws -> [RecognizedLine] {
        guard let cgImage = image.cgImage else { throw RecognitionError.invalidImage }
        let orientation = Self.orientation(for: image.imageOrientation)

        return try await Task.detached(priority: .userInitiated) {
            try Self.performRecognition(on: cgImage, orientation: orientation)
        }.value
    }

    nonisolated private static func performRecognition(on cgImage: CGImage,
                                                       orientation: CGImagePropertyOrientation) throws -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedLine(text: candidate.string,
                                  confidence: candidate.confidence,
                                  box: observation.boundingBox)
        }
    }

    nonisolated private static func orientation(for orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: .up
        case .upMirrored: .upMirrored
        case .down: .down
        case .downMirrored: .downMirrored
        case .left: .left
        case .leftMirrored: .leftMirrored
        case .right: .right
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

struct StaticTextRecognizer: TextRecognizing {
    var lines: [RecognizedLine] = []

    func recognize(_ image: UIImage) async throws -> [RecognizedLine] {
        lines
    }
}
