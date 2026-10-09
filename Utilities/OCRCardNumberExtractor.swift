import Foundation
import UIKit
import Vision

/// On-device OCR with ROI focus on collector-number zones (bottom / corners).
enum OCRCardNumberExtractor {
    struct Result: Sendable {
        var allLines: [String]
        /// Lines from bottom / corner ROIs — prefer for number parsing.
        var numberZoneLines: [String]
        var detectedNumbers: [String]
    }

    /// Full-frame + bottom-band + bottom-corner crops. Number zone is preferred for localId.
    static func recognize(_ cgImage: CGImage) async throws -> Result {
        let full = try await recognizeLines(in: cgImage)
        var zoneLines: [String] = []

        // Bottom ~32% (collector number strip on DE/EN TCG layouts)
        if let bottom = crop(cgImage, normalized: CGRect(x: 0, y: 0.68, width: 1, height: 0.32)) {
            zoneLines.append(contentsOf: (try? await recognizeLines(in: bottom)) ?? [])
        }
        // Bottom-left / bottom-right corners (number often left or right)
        if let bl = crop(cgImage, normalized: CGRect(x: 0, y: 0.72, width: 0.55, height: 0.28)) {
            zoneLines.append(contentsOf: (try? await recognizeLines(in: bl)) ?? [])
        }
        if let br = crop(cgImage, normalized: CGRect(x: 0.45, y: 0.72, width: 0.55, height: 0.28)) {
            zoneLines.append(contentsOf: (try? await recognizeLines(in: br)) ?? [])
        }

        let numbers = CardSearchQueryParser.extractCardNumbers(
            from: zoneLines + full,
            preferEarlier: true
        )

        return Result(
            allLines: dedupe(full + zoneLines),
            numberZoneLines: dedupe(zoneLines),
            detectedNumbers: numbers
        )
    }

    private static func recognizeLines(in cgImage: CGImage) async throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "en-US"]
        request.usesLanguageCorrection = false
        // Numbers/IDs — avoid “correcting” TG22 into words
        request.customWords = ["TG", "GG", "SV", "SWSH", "SM", "XY", "BW", "DP"]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            observation.topCandidates(3).map(\.string)
        }.flatMap { $0 }
    }

    /// `normalized` uses Vision-style origin bottom-left? We use top-left UIKit crop.
    private static func crop(_ image: CGImage, normalized rect: CGRect) -> CGImage? {
        let w = CGFloat(image.width)
        let h = CGFloat(image.height)
        let pixel = CGRect(
            x: rect.origin.x * w,
            y: rect.origin.y * h,
            width: rect.size.width * w,
            height: rect.size.height * h
        ).integral
        guard pixel.width > 8, pixel.height > 8 else { return nil }
        return image.cropping(to: pixel)
    }

    private static func dedupe(_ lines: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, seen.insert(t.lowercased()).inserted else { continue }
            out.append(t)
        }
        return out
    }
}
