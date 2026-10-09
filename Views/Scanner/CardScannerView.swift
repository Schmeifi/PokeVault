import SwiftUI
import SwiftData
import UIKit
import PhotosUI

/// Live AVFoundation preview + on-device OCR. Stitch Card Scanner chrome.
struct CardScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = CameraCaptureService()
    @State private var pickerItem: PhotosPickerItem?
    @State private var frozenFrame: UIImage?
    @State private var recognizedLines: [String] = []
    @State private var ranked: [RankedScanCandidate] = []
    @State private var status = "Kamera startet…"
    @State private var confidence: Double = 0
    @State private var confirmCandidate: RankedScanCandidate?
    @State private var hintsLabel = ""
    @State private var isScanning = false

    private let minConfirmConfidence = 0.72

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PV.spaceL) {
                headerBar
                viewfinder
                matchSheet
                if !recognizedLines.isEmpty {
                    ocrPanel
                }
            }
            .padding(.horizontal, PV.margin)
            .padding(.vertical, PV.spaceM)
            .pvDexAppear()
        }
        .pvScreenBackground()
        .navigationTitle("Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await camera.startIfPossible()
            updateStatusForCamera()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task {
                    await camera.startIfPossible()
                    updateStatusForCamera()
                }
            case .inactive, .background:
                camera.stop()
            @unknown default:
                break
            }
        }
        .onDisappear {
            camera.stop()
        }
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

    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(camera.isSessionRunning ? PV.primaryContainer : PV.inkMuted)
                    .frame(width: 10, height: 10)
                    .overlay {
                        if camera.isSessionRunning {
                            Circle()
                                .fill(PV.primaryContainer)
                                .frame(width: 10, height: 10)
                                .opacity(isScanning ? 0.2 : 1)
                                .scaleEffect(isScanning ? 1.8 : 1)
                                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isScanning || camera.isSessionRunning)
                        }
                    }
                Text(camera.isSessionRunning ? "AI Live Detector" : "Scanner")
                    .font(PV.labelBadge())
                    .foregroundStyle(PV.inkTitle)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: PV.ink.opacity(0.04), radius: 6, y: 2)

            Spacer()

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PV.onSurfaceVariant)
                    .frame(width: 40, height: 40)
                    .background(PV.sheet.opacity(0.95), in: Circle())
                    .shadow(color: PV.ink.opacity(0.06), radius: 6, y: 2)
            }
            .accessibilityLabel("Aus Mediathek wählen")
        }
    }

    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PV.radiusSheet, style: .continuous)
                .fill(PV.surfaceContainerLow)

            if let frozenFrame {
                Image(uiImage: frozenFrame)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if camera.availability == .ready {
                // Explicit `onTapFocus:` — trailing closure is ambiguous inside ViewBuilder.
                CameraPreviewView(
                    session: camera.session,
                    onTapFocus: { point, size in
                        camera.focus(at: point, viewSize: size)
                        status = "Fokus gesetzt — Kartennummer antippen falls unscharf"
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: PV.radiusSheet, style: .continuous))
            } else {
                cameraFallbackPlaceholder
            }

            ViewfinderBrackets()
                .padding(22)

            if isScanning {
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [.clear, PV.primaryContainer, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
                    .shadow(color: PV.primaryContainer.opacity(0.8), radius: 8)
                    .offset(y: -40)
            }

            VStack {
                Spacer()
                Text(status)
                    .font(PV.caption())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
                    .padding(.bottom, 12)
            }
        }
        .aspectRatio(4 / 5, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: PV.radiusSheet, style: .continuous))
        .shadow(color: PV.ink.opacity(0.06), radius: 12, y: 4)
        .overlay(alignment: .bottomTrailing) {
            if frozenFrame != nil {
                Button("Live") {
                    frozenFrame = nil
                    Task {
                        await camera.startIfPossible()
                        updateStatusForCamera()
                    }
                }
                .font(PV.labelBadge())
                .foregroundStyle(PV.onPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PV.primary, in: Capsule())
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private var cameraFallbackPlaceholder: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PV.sheet.opacity(0.85))
                    .frame(width: 72, height: 72)
                Image(systemName: "camera.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(PV.primary)
            }
            Text(fallbackTitle)
                .font(PV.labelBadge())
                .foregroundStyle(PV.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            if camera.availability == .denied || camera.availability == .restricted {
                Button("Einstellungen öffnen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(PV.caption())
                .foregroundStyle(PV.primary)
            }
        }
    }

    private var fallbackTitle: String {
        switch camera.availability {
        case .denied:
            return "Kamerazugriff verweigert — in den iOS-Einstellungen erlauben."
        case .restricted:
            return "Kamera eingeschränkt (Geräteverwaltung)."
        case .unavailable(let message):
            return message
        case .unknown:
            return "Kamera wird vorbereitet…"
        case .ready:
            return "Ziel erfassen"
        }
    }

    private var matchSheet: some View {
        VStack(alignment: .leading, spacing: PV.spaceM) {
            Capsule()
                .fill(PV.surfaceVariant)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kandidaten")
                        .font(PV.headline())
                        .foregroundStyle(PV.inkTitle)
                    Text("Max. \(ScanMatchService.maxCandidates) · Match-Qualität (Name/Nummer/Set)")
                        .font(PV.caption())
                        .foregroundStyle(PV.inkSecondary)
                }
                Spacer()
                Text(String(format: "%.0f %%", confidence * 100))
                    .font(PV.readout(.title3))
                    .foregroundStyle(confidence >= minConfirmConfidence ? PV.primary : PV.secondary)
                    .contentTransition(.numericText())
            }

            if !hintsLabel.isEmpty {
                Text("OCR: \(hintsLabel)")
                    .font(PV.caption())
                    .foregroundStyle(PV.inkMuted)
            }

            Button {
                Task { await captureFromCamera() }
            } label: {
                Label(
                    camera.isSessionRunning ? "Karte scannen" : "Kamera nicht bereit",
                    systemImage: "camera.viewfinder"
                )
                .font(PV.headline())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(PV.onPrimary)
                .background(
                    (camera.isSessionRunning && !isScanning ? PV.primary : PV.inkMuted),
                    in: RoundedRectangle(cornerRadius: PV.radiusDefault, style: .continuous)
                )
            }
            .disabled(!camera.isSessionRunning || isScanning)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Aus Mediathek wählen", systemImage: "photo")
                    .font(PV.bodyStrong())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(PV.primary)
                    .background(
                        PV.surfaceContainer,
                        in: RoundedRectangle(cornerRadius: PV.radiusDefault, style: .continuous)
                    )
            }

            if !camera.activeDeviceDescription.isEmpty {
                Text("Kamera: \(camera.activeDeviceDescription)")
                    .font(PV.caption())
                    .foregroundStyle(PV.inkMuted)
                    .lineLimit(2)
            }

            if ranked.isEmpty {
                Text("Nah an die Karte halten · Viewfinder antippen für Fokus (Kartennummer unten). Speichern nur nach Bestätigung.")
                    .font(PV.body())
                    .foregroundStyle(PV.inkSecondary)
            } else {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, item in
                    Button {
                        confirmCandidate = item
                    } label: {
                        RankedMatchRow(item: item, rank: index + 1, strong: item.matchConfidence >= minConfirmConfidence)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(PV.spaceL)
        .background(
            RoundedRectangle(cornerRadius: PV.radiusSheet, style: .continuous)
                .fill(PV.sheet)
                .shadow(color: PV.ink.opacity(0.08), radius: 20, y: -8)
        )
    }

    private var ocrPanel: some View {
        PVScreenPanel {
            Text("OCR-Text")
                .font(PV.headline())
                .foregroundStyle(PV.primary)
            ForEach(recognizedLines.prefix(8), id: \.self) { line in
                Text(line)
                    .font(PV.monoCaption())
                    .foregroundStyle(PV.ink)
            }
        }
    }

    private func updateStatusForCamera() {
        switch camera.availability {
        case .ready:
            if frozenFrame == nil {
                status = "Karte im Rahmen ausrichten — dann „Karte scannen“."
            }
        case .denied:
            status = "Kein Kamerazugriff — Mediathek nutzen oder in Einstellungen erlauben."
        case .restricted:
            status = "Kamera eingeschränkt — Mediathek nutzen."
        case .unavailable(let message):
            status = message
        case .unknown:
            status = "Kamera startet…"
        }
    }

    private func captureFromCamera() async {
        status = "Aufnahme…"
        isScanning = true
        ranked = []
        confidence = 0
        hintsLabel = ""
        defer { isScanning = false }
        guard let image = await camera.capturePhoto() else {
            status = "Aufnahme fehlgeschlagen — erneut versuchen oder Mediathek nutzen."
            return
        }
        await processImage(image)
    }

    private func handlePick(_ item: PhotosPickerItem) async {
        status = "Bild wird geladen…"
        isScanning = true
        ranked = []
        confidence = 0
        hintsLabel = ""
        defer { isScanning = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                status = "Bild konnte nicht gelesen werden."
                return
            }
            camera.stop()
            await processImage(uiImage)
        } catch {
            status = error.localizedDescription
        }
    }

    private func processImage(_ uiImage: UIImage) async {
        frozenFrame = uiImage
        guard let cgImage = uiImage.cgImage else {
            status = "Bild konnte nicht gelesen werden."
            return
        }
        status = "OCR (Kartennummer)…"
        do {
            let ocr = try await OCRCardNumberExtractor.recognize(cgImage)
            recognizedLines = ocr.allLines
            var hints = ScanMatchService.extractHints(
                from: ocr.allLines,
                numberPriorityLines: ocr.numberZoneLines
            )
            // ROI-Nummern explizit voranstellen
            for num in ocr.detectedNumbers.reversed() {
                if !hints.localIds.contains(where: { $0.caseInsensitiveCompare(num) == .orderedSame }) {
                    hints.localIds.insert(num, at: 0)
                }
            }
            hintsLabel = hints.primaryQueryLabel

            guard !hints.isEmpty else {
                status = "Keine Kartennummer erkannt — Nummer ins Bild (unten) halten oder Mediathek."
                confidence = 0
                return
            }

            if hints.localIds.isEmpty {
                status = "Name erkannt, aber keine Nummer — Suche eingeschränkt…"
            } else {
                status = "Nummer \(hints.localIds.first ?? "") — suche Kandidaten…"
            }

            let found = try await ScanMatchService.findCandidates(hints: hints)
            ranked = found
            confidence = ScanMatchService.overallConfidence(from: found)

            if found.isEmpty {
                status = "Keine passenden Kandidaten für \(hints.primaryQueryLabel)."
            } else if let top = found.first, hints.localIds.contains(where: {
                $0.caseInsensitiveCompare(top.card.localId ?? "") == .orderedSame
                    || top.matchReasons.contains(where: { $0.localizedCaseInsensitiveContains("Nummer") })
            }) {
                status = "Nummer-Treffer · \(String(format: "%.0f %%", confidence * 100))"
            } else {
                status = "Target Locked · \(String(format: "%.0f %%", confidence * 100))"
            }

            let scan = CardScanResult(
                recognizedText: ocr.allLines.joined(separator: "\n"),
                confidence: confidence,
                status: .needsReview,
                note: "OCR lokal — Nummer-ROI + Match-Konfidenz"
            )
            modelContext.insert(scan)
            try? modelContext.save()
        } catch {
            status = error.localizedDescription
        }
    }
}

private struct ViewfinderBrackets: View {
    var body: some View {
        GeometryReader { geo in
            let w: CGFloat = 28
            let t: CGFloat = 4
            let color = PV.primaryContainer
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: w))
                    p.addLine(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: w, y: 0))
                }
                .stroke(color, style: StrokeStyle(lineWidth: t, lineCap: .round, lineJoin: .round))
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width - w, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width, y: w))
                }
                .stroke(color, style: StrokeStyle(lineWidth: t, lineCap: .round, lineJoin: .round))
                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height - w))
                    p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    p.addLine(to: CGPoint(x: w, y: geo.size.height))
                }
                .stroke(color, style: StrokeStyle(lineWidth: t, lineCap: .round, lineJoin: .round))
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width - w, y: geo.size.height))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - w))
                }
                .stroke(color, style: StrokeStyle(lineWidth: t, lineCap: .round, lineJoin: .round))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct RankedMatchRow: View {
    let item: RankedScanCandidate
    let rank: Int
    let strong: Bool

    private var tone: PV.ElementTone {
        .from(seed: item.card.name + item.card.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(PV.labelID())
                .foregroundStyle(PV.inkMuted)
                .frame(width: 22)

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tone.hero)
                    .frame(width: 48, height: 66)
                CachedCardImageView(
                    candidates: item.card.imageCandidatesLow,
                    title: item.card.name,
                    size: CGSize(width: 44, height: 62)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.card.name)
                    .font(PV.headline())
                    .foregroundStyle(PV.inkTitle)
                    .lineLimit(1)
                Text(item.card.id)
                    .font(PV.monoCaption())
                    .foregroundStyle(PV.inkSecondary)
                if !item.matchReasons.isEmpty {
                    Text(item.matchReasons.joined(separator: " · "))
                        .font(PV.caption())
                        .foregroundStyle(PV.inkMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Text(String(format: "%.0f%%", item.matchConfidence * 100))
                .font(PV.statNumber())
                .foregroundStyle(strong ? PV.onPrimaryContainer : PV.onSecondaryContainer)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(strong ? PV.primaryContainer.opacity(0.35) : PV.secondaryContainer.opacity(0.35))
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: PV.radiusDefault, style: .continuous)
                .fill(PV.surfaceContainerLow)
        )
    }
}

struct ConfirmScanCandidateView: View {
    let candidate: RankedScanCandidate
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?

    private var tone: PV.ElementTone {
        .from(seed: candidate.card.name + candidate.card.id)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PV.spaceL) {
                PVTypeColoredCard(tone: tone, minHeight: 120) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(candidate.card.name)
                                .font(PV.title())
                                .foregroundStyle(tone.onHero)
                            Text(candidate.card.id)
                                .font(PV.labelID())
                                .foregroundStyle(tone.onHero.opacity(0.8))
                            Text(String(format: "%.0f %% Match", candidate.matchConfidence * 100))
                                .font(PV.statNumber())
                                .foregroundStyle(tone.onHero)
                        }
                        Spacer()
                        CachedCardImageView(
                            candidates: candidate.card.imageCandidatesHigh,
                            title: candidate.card.name,
                            size: CGSize(width: 90, height: 126)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                if !candidate.matchReasons.isEmpty {
                    PVScreenPanel {
                        Text("Match-Gründe")
                            .font(PV.headline())
                            .foregroundStyle(PV.primary)
                        Text(candidate.matchReasons.joined(separator: ", "))
                            .font(PV.body())
                            .foregroundStyle(PV.ink)
                    }
                }

                Button {
                    Task { await save() }
                } label: {
                    Text("In Sammlung übernehmen")
                        .font(PV.headline())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(PV.onPrimary)
                        .background(PV.primary, in: RoundedRectangle(cornerRadius: PV.radiusDefault, style: .continuous))
                }
                .disabled(candidate.matchConfidence < 0.35)
                .opacity(candidate.matchConfidence < 0.35 ? 0.5 : 1)

                if let message {
                    Text(message)
                        .font(PV.caption())
                        .foregroundStyle(PV.secondary)
                }
            }
            .padding(PV.margin)
        }
        .pvScreenBackground()
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
    /// Legacy helper — prefer `OCRCardNumberExtractor` for scans.
    static func recognize(cgImage: CGImage) async throws -> [String] {
        try await OCRCardNumberExtractor.recognize(cgImage).allLines
    }
}
