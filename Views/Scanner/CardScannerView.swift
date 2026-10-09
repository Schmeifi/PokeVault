import SwiftUI
import SwiftData
import Vision
import UIKit
import PhotosUI

/// On-device OCR (Vision). Keine Cloud-KI. Speichern nur nach Bestätigung.
struct CardScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var pickerItem: PhotosPickerItem?
    @State private var recognizedLines: [String] = []
    @State private var ranked: [RankedScanCandidate] = []
    @State private var status = "Foto wählen — OCR läuft lokal auf dem Gerät."
    @State private var confidence: Double = 0
    @State private var confirmCandidate: RankedScanCandidate?
    @State private var hintsLabel = ""

    private let minConfirmConfidence = 0.72

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PV.spaceL) {
                PVBrandHeader(subtitle: "Scanner — Vision OCR (DE/EN), offline")

                PVScreenPanel {
                    Text(status)
                        .font(PV.body())
                        .foregroundStyle(PV.onScreen)
                    Text("Match-Konfidenz: \(String(format: "%.0f %%", confidence * 100))")
                        .font(PV.readout(.callout))
                        .foregroundStyle(confidence >= minConfirmConfidence ? PV.statusOK : PV.statusWarn)
                        .contentTransition(.numericText())
                    if !hintsLabel.isEmpty {
                        Text("OCR-Hinweise: \(hintsLabel)")
                            .font(PV.caption())
                            .foregroundStyle(PV.onScreenMuted)
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Kartenfoto wählen", systemImage: "camera.viewfinder")
                            .font(PV.headline())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PV.readout)
                    .foregroundStyle(PV.screen)

                    Text("Konfidenz = Match-Qualität (Name/Nummer/Set), nicht OCR-Textmenge. Max. \(ScanMatchService.maxCandidates) Kandidaten. Speichern nur nach Bestätigung.")
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

                if !ranked.isEmpty {
                    PVScreenPanel {
                        Text("Kandidaten (\(ranked.count)) — bitte bestätigen")
                            .font(PV.headline())
                            .foregroundStyle(PV.onScreen)
                        ForEach(ranked) { item in
                            Button {
                                confirmCandidate = item
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    CardSearchResultRow(hit: item.hit, actionTitle: "Wählen")
                                    HStack {
                                        Text(String(format: "%.0f %% Match", item.matchConfidence * 100))
                                            .font(PV.monoCaption())
                                            .foregroundStyle(item.matchConfidence >= minConfirmConfidence ? PV.statusOK : PV.statusWarn)
                                        if !item.matchReasons.isEmpty {
                                            Text(item.matchReasons.joined(separator: " · "))
                                                .font(PV.caption())
                                                .foregroundStyle(PV.onScreenMuted)
                                                .lineLimit(1)
                                        }
                                    }
                                }
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
        .sheet(item: $confirmCandidate) { item in
            NavigationStack {
                ConfirmScanCandidateView(candidate: item)
            }
            .pvThemedSheet()
        }
    }

    private func handlePick(_ item: PhotosPickerItem) async {
        status = "OCR läuft…"
        ranked = []
        confidence = 0
        hintsLabel = ""
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let cgImage = UIImage(data: data)?.cgImage else {
                status = "Bild konnte nicht gelesen werden."
                return
            }
            let texts = try await OCRService.recognize(cgImage: cgImage)
            recognizedLines = texts
            let hints = ScanMatchService.extractHints(from: texts)
            hintsLabel = hints.primaryQueryLabel

            guard !hints.isEmpty else {
                status = "Kein klarer Name/Nummer erkannt."
                confidence = 0
                return
            }

            status = "Suche Kandidaten: \(hints.primaryQueryLabel)…"
            let found = try await ScanMatchService.findCandidates(hints: hints)
            ranked = found
            confidence = ScanMatchService.overallConfidence(from: found)

            if found.isEmpty {
                status = "Keine passenden Kandidaten für \(hints.primaryQueryLabel)."
            } else {
                status = "\(found.count) Kandidat(en) — Top-Match \(String(format: "%.0f %%", confidence * 100)). Bitte bestätigen."
            }

            let scan = CardScanResult(
                recognizedText: texts.joined(separator: "\n"),
                confidence: confidence,
                status: .needsReview,
                note: "OCR lokal — Match-Konfidenz, Bestätigung nötig"
            )
            modelContext.insert(scan)
            try? modelContext.save()
        } catch {
            status = error.localizedDescription
        }
    }
}

struct ConfirmScanCandidateView: View {
    let candidate: RankedScanCandidate
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    CachedCardImageView(
                        candidates: candidate.card.imageCandidatesHigh,
                        title: candidate.card.name,
                        size: CGSize(width: 120, height: 168)
                    )
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Kandidat") {
                LabeledContent("Name", value: candidate.card.name)
                LabeledContent("ID", value: candidate.card.id)
                LabeledContent("Match", value: String(format: "%.0f %%", candidate.matchConfidence * 100))
                if !candidate.matchReasons.isEmpty {
                    LabeledContent("Gründe", value: candidate.matchReasons.joined(separator: ", "))
                }
            }
            .listRowBackground(PV.screenElevated)
            .foregroundStyle(PV.onScreen)

            Section {
                Button("In Sammlung übernehmen") {
                    Task { await save() }
                }
                .foregroundStyle(PV.readout)
                .disabled(candidate.matchConfidence < 0.35)
            }
            .listRowBackground(PV.screenElevated)

            if let message {
                Text(message)
                    .font(PV.caption())
                    .foregroundStyle(PV.statusWarn)
            }
        }
        .scrollContentBackground(.hidden)
        .pvScreenBackground()
        .navigationTitle("Bestätigen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schließen") { dismiss() }
                    .foregroundStyle(PV.onChassis)
            }
        }
    }

    private func save() async {
        do {
            let entry = try await CatalogImportService().importCard(id: candidate.card.id, locale: "de", in: modelContext)
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
}
