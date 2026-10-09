import SwiftUI
import SwiftData
import Vision
import UIKit
import PhotosUI

/// On-device OCR (Vision). Keine Cloud-KI. Kein Auto-Save bei niedriger Konfidenz.
struct CardScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var pickerItem: PhotosPickerItem?
    @State private var recognizedLines: [String] = []
    @State private var candidates: [TCGdexCardSummary] = []
    @State private var status = "Foto wählen — OCR läuft lokal auf dem Gerät."
    @State private var confidence: Double = 0
    @State private var confirmCard: TCGdexCardSummary?

    private let minConfirmConfidence = 0.72

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PV.spaceL) {
                PVBrandHeader(subtitle: "Scanner — Vision OCR (DE/EN), offline")

                PVScreenPanel {
                    Text(status)
                        .font(PV.body())
                        .foregroundStyle(PV.onScreen)
                    Text("Konfidenz: \(String(format: "%.0f %%", confidence * 100))")
                        .font(PV.readout(.callout))
                        .foregroundStyle(confidence >= minConfirmConfidence ? PV.statusOK : PV.statusWarn)
                        .contentTransition(.numericText())

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Kartenfoto wählen", systemImage: "camera.viewfinder")
                            .font(PV.headline())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PV.readout)
                    .foregroundStyle(PV.screen)

                    Text("Architektur für Live-Kamera/Batch vorbereitet. Speichern nur nach Bestätigung — nie bei niedriger Konfidenz automatisch.")
                        .font(PV.caption())
                        .foregroundStyle(PV.onScreenMuted)
                }

                if !recognizedLines.isEmpty {
                    PVScreenPanel {
                        Text("OCR-Text")
                            .font(PV.headline())
                            .foregroundStyle(PV.readout)
                        ForEach(recognizedLines.prefix(12), id: \.self) { line in
                            Text(line)
                                .font(PV.monoCaption())
                                .foregroundStyle(PV.onScreen)
                        }
                    }
                }

                if !candidates.isEmpty {
                    PVScreenPanel {
                        Text("Kandidaten — bitte bestätigen")
                            .font(PV.headline())
                            .foregroundStyle(PV.onScreen)
                        ForEach(candidates) { card in
                            Button {
                                confirmCard = card
                            } label: {
                                CardSearchResultRow(card: card, actionTitle: "Wählen")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
            .pvDexAppear()
        }
        .pvScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await handlePick(item) }
        }
        .sheet(item: $confirmCard) { card in
            NavigationStack {
                ConfirmScanCandidateView(card: card, confidence: confidence)
            }
        }
    }

    private func handlePick(_ item: PhotosPickerItem) async {
        status = "OCR läuft…"
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let cgImage = UIImage(data: data)?.cgImage else {
                status = "Bild konnte nicht gelesen werden."
                return
            }
            let texts = try await OCRService.recognize(cgImage: cgImage)
            recognizedLines = texts
            confidence = texts.isEmpty ? 0 : min(0.95, 0.35 + Double(texts.count) * 0.08)
            let query = OCRService.guessQuery(from: texts)
            status = query.isEmpty ? "Kein klarer Name/Nummer erkannt." : "Suche: \(query)"
            if !query.isEmpty {
                let parsed = CardSearchQueryParser.parse(freeText: query)
                let q = TCGdexCardSearchQuery(
                    name: parsed.name,
                    localId: parsed.localId,
                    itemsPerPage: 12
                )
                candidates = try await TCGdexProvider.shared.searchCardsBilingual(
                    q,
                    localIdAlternates: parsed.localIdAlternates,
                    primaryLocale: "de",
                    secondaryLocale: "en"
                )
            } else {
                candidates = []
            }
            let scan = CardScanResult(
                recognizedText: texts.joined(separator: "\n"),
                confidence: confidence,
                status: .needsReview,
                note: "OCR lokal — Bestätigung nötig"
            )
            modelContext.insert(scan)
            try? modelContext.save()
        } catch {
            status = error.localizedDescription
        }
    }
}

struct ConfirmScanCandidateView: View {
    let card: TCGdexCardSummary
    let confidence: Double
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?

    var body: some View {
        Form {
            Section("Kandidat") {
                HStack {
                    Spacer()
                    CachedCardImageView(
                        candidates: card.imageCandidatesHigh,
                        title: card.name,
                        size: CGSize(width: 120, height: 168)
                    )
                    Spacer()
                }
                LabeledContent("Name", value: card.name)
                LabeledContent("ID", value: card.id)
                LabeledContent("OCR-Konfidenz", value: String(format: "%.0f %%", confidence * 100))
            }
            Section {
                Button("In Sammlung übernehmen") {
                    Task { await save() }
                }
            }
            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Bestätigen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schließen") { dismiss() }
            }
        }
    }

    private func save() async {
        do {
            let entry = try await CatalogImportService().importCard(id: card.id, locale: "de", in: modelContext)
            modelContext.insert(OwnedCard(catalogEntry: entry, quantity: 1))
            try modelContext.save()
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

enum OCRService {
    static func recognize(cgImage: CGImage) async throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "en-US"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }

    static func guessQuery(from lines: [String]) -> String {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if CardSearchQueryParser.looksLikeCardNumber(trimmed) {
                return CardSearchQueryParser.splitCardNumber(trimmed).primary
            }
        }
        return lines.first(where: { $0.count >= 3 && $0.count <= 40 })?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
