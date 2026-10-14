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
        /// Full-frame lines with vertical position (0 = top of the card).
        var positionedLines: [CardIdentityParser.Line] = []
    }

    /// Full-frame observations with position, plus an upscaled bottom-left crop for `005/078`.
    static func recognize(_ cgImage: CGImage) async throws -> Result {
        let positioned = try await recognizePositioned(in: cgImage)
        var zoneLines: [String] = []

        // Bottom-left corner is the collector number (`005/078`), not the set symbol on the right.
        if let corner = crop(cgImage, normalized: CGRect(x: 0.0, y: 0.80, width: 0.48, height: 0.18)),
           let scaled = scale(corner, factor: 3) {
            zoneLines.append(contentsOf: (try? await recognizeLines(in: scaled)) ?? [])
        }
        // Bottom strip holds the collector number and illustrator credit.
        if let bottom = crop(cgImage, normalized: CGRect(x: 0, y: 0.68, width: 1, height: 0.32)),
           let scaled = scale(bottom, factor: 2) {
            zoneLines.append(contentsOf: (try? await recognizeLines(in: scaled)) ?? [])
        }
        if let bl = crop(cgImage, normalized: CGRect(x: 0, y: 0.70, width: 0.62, height: 0.30)),
           let scaled = scale(bl, factor: 2) {
            zoneLines.append(contentsOf: (try? await recognizeLines(in: scaled)) ?? [])
        }
        if let br = crop(cgImage, normalized: CGRect(x: 0.38, y: 0.70, width: 0.62, height: 0.30)),
           let scaled = scale(br, factor: 2) {
            zoneLines.append(contentsOf: (try? await recognizeLines(in: scaled)) ?? [])
        }

        let full = positioned.map(\.text)
        let numbers = CardSearchQueryParser.extractCardNumbers(
            from: zoneLines + full,
            preferEarlier: true
        )

        return Result(
            allLines: dedupe(full + zoneLines),
            numberZoneLines: dedupe(zoneLines),
            detectedNumbers: numbers,
            positionedLines: positioned
        )
    }

    private static func recognizePositioned(in cgImage: CGImage) async throws -> [CardIdentityParser.Line] {
        let request = makeRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        return (request.results ?? []).map { observation in
            let text = observation.topCandidates(1).first?.string ?? ""
            // Vision boxes use a bottom-left origin.
            let topFraction = 1 - Double(observation.boundingBox.midY)
            return CardIdentityParser.Line(text: text, topFraction: min(1, max(0, topFraction)))
        }.filter { !$0.text.isEmpty }
    }

    private static func makeRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "en-US"]
        request.usesLanguageCorrection = false
        request.customWords = ["TG", "GG", "SV", "SWSH", "SM", "XY", "BW", "DP", "Illus", "HP", "KP"]
        return request
    }

    private static func recognizeLines(in cgImage: CGImage) async throws -> [String] {
        let request = makeRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            observation.topCandidates(3).map(\.string)
        }.flatMap { $0 }
    }

    private static func scale(_ image: CGImage, factor: CGFloat) -> CGImage? {
        guard factor > 1 else { return image }
        let width = Int((CGFloat(image.width) * factor).rounded())
        let height = Int((CGFloat(image.height) * factor).rounded())
        guard width > 8, height > 8 else { return image }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
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

extension UIImage {
    /// AVFoundation photos are often stored rotated. `cgImage` ignores orientation,
    /// which put the V-rule at the “top” and hid the Pokémon name.
    func uprightCGImage() -> CGImage? {
        if imageOrientation == .up { return cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}
