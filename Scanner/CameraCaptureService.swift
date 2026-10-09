import AVFoundation
import Combine
import UIKit
import SwiftUI

/// Close-up card scanner camera (AVFoundation).
///
/// Tuned for Pokémon TCG collector-number OCR at ~12–20 cm:
/// - Physical **wide** lens only (never ultra-wide / dual-wide virtual auto-macro).
/// - High-res `.photo` session preset (fallback 4K / `.high`).
/// - Near-range continuous AF, periodic number-strip AF pulses, tap → AF → optional lock.
/// - Accurate POI via shared `AVCaptureVideoPreviewLayer.captureDevicePointConverted`.
/// - Optional torch (default off — foil glare).
final class CameraCaptureService: NSObject, ObservableObject {
    enum CameraAvailability: Equatable {
        case unknown
        case ready
        case denied
        case restricted
        case unavailable(String)
    }

    enum FocusUIState: Equatable {
        case idle
        case adjusting
        case tracking
        case locked
    }

    @Published private(set) var availability: CameraAvailability = .unknown
    @Published private(set) var isSessionRunning = false
    @Published private(set) var activeDeviceDescription: String = ""
    @Published private(set) var focusState: FocusUIState = .idle
    @Published private(set) var minimumFocusDistanceCm: Double?
    @Published private(set) var distanceHint: String =
        "Karte ruhig halten · ca. 15 cm Abstand · Nummernleiste antippen"
    @Published private(set) var torchAvailable = false
    @Published private(set) var torchEnabled = false
    @Published private(set) var focusLocked = false

    let session = AVCaptureSession()
    /// Shared with preview for accurate point conversion — do not create a second layer.
    let previewLayer = AVCaptureVideoPreviewLayer()

    private let sessionQueue = DispatchQueue(label: "com.pokevault.collection.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?
    private var isConfigured = false
    private var videoDevice: AVCaptureDevice?
    private var subjectAreaObserver: NSObjectProtocol?
    private var focusPulseTimer: DispatchSourceTimer?
    private var adjustingKVO: NSKeyValueObservation?
    /// Session-queue flag — avoid `main.sync` from AF timers.
    private var focusLockedOnSessionQueue = false
    private var lastTapDevicePoint: CGPoint = CGPoint(x: 0.5, y: 0.82)

    // Number-strip bias in layer/normalized preview coords (y down).
    private let numberStripPoint = CGPoint(x: 0.5, y: 0.82)

    @MainActor
    func startIfPossible() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized: break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { availability = .denied; return }
        case .denied: availability = .denied; return
        case .restricted: availability = .restricted; return
        @unknown default:
            availability = .unavailable("Kamerastatus unbekannt.")
            return
        }

        let configured = await configureSessionIfNeeded()
        guard configured else { return }
        availability = .ready
        await startSession()
        pulseAutoFocus(atLayerNormalized: numberStripPoint, thenLock: false)
        startFocusPulseTimer()
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.focusPulseTimer?.cancel()
            self.focusPulseTimer = nil
            self.adjustingKVO = nil
            if let observer = self.subjectAreaObserver {
                NotificationCenter.default.removeObserver(observer)
                self.subjectAreaObserver = nil
            }
            self.setTorchOnSessionQueue(false)
            self.focusLockedOnSessionQueue = false
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isSessionRunning = false
                self.focusState = .idle
                self.torchEnabled = false
                self.focusLocked = false
            }
        }
    }

    /// Tap in preview **view** coordinates — converted via previewLayer to device POI.
    func focus(at viewPoint: CGPoint, viewSize: CGSize) {
        guard viewSize.width > 1, viewSize.height > 1 else { return }
        let layerBounds = previewLayer.bounds
        let devicePoint: CGPoint
        if layerBounds.width > 1, layerBounds.height > 1 {
            let layerPoint = CGPoint(
                x: viewPoint.x / viewSize.width * layerBounds.width,
                y: viewPoint.y / viewSize.height * layerBounds.height
            )
            devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
        } else {
            // Portrait fallback before first layout (device coords: x=vertical, y=horizontal).
            devicePoint = CGPoint(
                x: min(1, max(0, viewPoint.y / viewSize.height)),
                y: min(1, max(0, 1 - viewPoint.x / viewSize.width))
            )
        }
        lastTapDevicePoint = devicePoint
        sessionQueue.async { self.focusLockedOnSessionQueue = false }
        DispatchQueue.main.async {
            self.focusLocked = false
            self.focusState = .adjusting
        }
        pulseAutoFocus(devicePoint: devicePoint, thenLock: true)
    }

    func setTorchEnabled(_ on: Bool) {
        DispatchQueue.main.async { self.torchEnabled = on }
        sessionQueue.async { self.setTorchOnSessionQueue(on) }
    }

    func setFocusLocked(_ locked: Bool) {
        if locked {
            lockFocusAtCurrentLensPosition()
        } else {
            unlockFocusToNearContinuous()
        }
    }

    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard self.session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                if self.photoContinuation != nil {
                    continuation.resume(returning: nil)
                    return
                }
                if !self.focusLockedOnSessionQueue {
                    self.pulseAutoFocusOnSessionQueue(
                        devicePoint: self.lastTapDevicePoint,
                        thenLock: false
                    )
                }
                self.photoContinuation = continuation
                var settings = AVCapturePhotoSettings()
                if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                    settings = AVCapturePhotoSettings(
                        format: [AVVideoCodecKey: AVVideoCodecType.jpeg]
                    )
                }
                settings.flashMode = .off
                if #available(iOS 16.0, *) {
                    settings.photoQualityPrioritization = .quality
                }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    // MARK: - Session

    private func configureSessionIfNeeded() async -> Bool {
        if isConfigured { return true }
        return await withCheckedContinuation { continuation in
            sessionQueue.async {
                self.session.beginConfiguration()
                if self.session.canSetSessionPreset(.photo) {
                    self.session.sessionPreset = .photo
                } else if self.session.canSetSessionPreset(.hd4K3840x2160) {
                    self.session.sessionPreset = .hd4K3840x2160
                } else {
                    self.session.sessionPreset = .high
                }

                guard let device = Self.selectBackCameraForCloseUpOCR() else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.availability = .unavailable(
                            "Keine Kamera verfügbar (Simulator?). Nutze Foto-Bibliothek."
                        )
                        continuation.resume(returning: false)
                    }
                    return
                }

                do {
                    try Self.configureDeviceForCloseUp(device)
                } catch {
                    NSLog("[PokeVault] Camera configure warning: \(error)")
                }

                guard let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.availability = .unavailable("Kamera-Eingang nicht verfügbar.")
                        continuation.resume(returning: false)
                    }
                    return
                }
                self.session.addInput(input)
                self.videoDevice = device

                guard self.session.canAddOutput(self.photoOutput) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.availability = .unavailable("Foto-Ausgabe nicht verfügbar.")
                        continuation.resume(returning: false)
                    }
                    return
                }
                self.session.addOutput(self.photoOutput)
                if #available(iOS 16.0, *) {
                    self.photoOutput.maxPhotoQualityPrioritization = .quality
                }

                self.previewLayer.session = self.session
                self.previewLayer.videoGravity = .resizeAspectFill

                self.session.commitConfiguration()
                self.isConfigured = true

                let minCm = Self.minimumFocusDistanceCentimeters(for: device)
                let desc = Self.describe(device, minCm: minCm)
                NSLog("[PokeVault] Scanner camera: \(desc)")
                self.installObservers(for: device)

                let torchOK = device.hasTorch && device.isTorchAvailable
                let hint: String
                if let minCm, minCm > 12 {
                    hint = String(
                        format: "Mindestabstand ~%.0f cm · ruhig halten · Nummernleiste antippen",
                        minCm
                    )
                } else {
                    hint = "Karte ruhig halten · ca. 15 cm · Nummernleiste (unten) antippen"
                }

                DispatchQueue.main.async {
                    self.activeDeviceDescription = desc
                    self.minimumFocusDistanceCm = minCm
                    self.distanceHint = hint
                    self.torchAvailable = torchOK
                    continuation.resume(returning: true)
                }
            }
        }
    }

    private func startSession() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                let running = self.session.isRunning
                DispatchQueue.main.async {
                    self.isSessionRunning = running
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Device selection & config

    /// Physical wide only. Never ultra-wide / dual-wide / triple (auto-macro soft path).
    static func selectBackCameraForCloseUpOCR() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        if let wide = discovery.devices.first {
            return wide
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
    }

    static func configureDeviceForCloseUp(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        // Mild zoom for number-strip framing; stay on physical wide (no virtual-lens APIs).
        let formatMax = device.activeFormat.videoMaxZoomFactor
        let deviceMax = device.maxAvailableVideoZoomFactor
        let targetZoom = min(1.5, formatMax, deviceMax)
        if targetZoom >= 1.05 {
            device.videoZoomFactor = targetZoom
        }

        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        } else if device.isFocusModeSupported(.autoFocus) {
            device.focusMode = .autoFocus
        }

        if device.isAutoFocusRangeRestrictionSupported {
            device.autoFocusRangeRestriction = .near
        }

        if device.isSmoothAutoFocusSupported {
            // Off: smoother AF can lag / feel stuck on close cards.
            device.isSmoothAutoFocusEnabled = false
        }

        device.isSubjectAreaChangeMonitoringEnabled = true

        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        // Slight positive bias — card stock is often underexposed indoors.
        let bias = min(device.maxExposureTargetBias, max(device.minExposureTargetBias, 0.35))
        device.setExposureTargetBias(bias, completionHandler: nil)

        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }

        if device.isLowLightBoostSupported {
            device.automaticallyEnablesLowLightBoostWhenAvailable = true
        }
    }

    static func minimumFocusDistanceCentimeters(for device: AVCaptureDevice) -> Double? {
        let mm = device.minimumFocusDistance
        guard mm > 0 else { return nil }
        return Double(mm) / 10.0
    }

    static func describe(_ device: AVCaptureDevice, minCm: Double?) -> String {
        var parts: [String] = [
            device.localizedName,
            device.deviceType.rawValue
        ]
        if let minCm {
            parts.append(String(format: "minFocus≈%.0fcm", minCm))
        }
        if device.isAutoFocusRangeRestrictionSupported {
            parts.append("AF=near")
        }
        parts.append(String(format: "zoom=%.1fx", device.videoZoomFactor))
        return parts.joined(separator: " · ")
    }

    // MARK: - Focus engine

    private func startFocusPulseTimer() {
        sessionQueue.async {
            self.focusPulseTimer?.cancel()
            let timer = DispatchSource.makeTimerSource(queue: self.sessionQueue)
            timer.schedule(deadline: .now() + 1.2, repeating: 1.6)
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                guard !self.focusLockedOnSessionQueue else { return }
                self.pulseAutoFocusOnSessionQueue(
                    devicePoint: self.lastTapDevicePoint,
                    thenLock: false
                )
            }
            timer.resume()
            self.focusPulseTimer = timer
        }
    }

    private func pulseAutoFocus(atLayerNormalized point: CGPoint, thenLock: Bool) {
        sessionQueue.async {
            let devicePoint: CGPoint
            let bounds = self.previewLayer.bounds
            if bounds.width > 1, bounds.height > 1 {
                let layerPt = CGPoint(x: point.x * bounds.width, y: point.y * bounds.height)
                devicePoint = self.previewLayer.captureDevicePointConverted(fromLayerPoint: layerPt)
            } else {
                devicePoint = CGPoint(x: point.y, y: 1 - point.x)
            }
            self.lastTapDevicePoint = devicePoint
            self.pulseAutoFocusOnSessionQueue(devicePoint: devicePoint, thenLock: thenLock)
        }
    }

    private func pulseAutoFocus(devicePoint: CGPoint, thenLock: Bool) {
        sessionQueue.async {
            self.pulseAutoFocusOnSessionQueue(devicePoint: devicePoint, thenLock: thenLock)
        }
    }

    private func pulseAutoFocusOnSessionQueue(devicePoint: CGPoint, thenLock: Bool) {
        guard let device = videoDevice else { return }
        let poi = CGPoint(
            x: min(1, max(0, devicePoint.x)),
            y: min(1, max(0, devicePoint.y))
        )
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = poi
            }
            // Force a real AF cycle (CAF alone often won't re-hunt at close range).
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            } else if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = poi
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
        } catch {
            NSLog("[PokeVault] AF pulse failed: \(error)")
            return
        }

        DispatchQueue.main.async { self.focusState = .adjusting }

        if thenLock {
            sessionQueue.asyncAfter(deadline: .now() + 0.75) { [weak self] in
                self?.lockFocusAtCurrentLensPositionOnSessionQueue()
            }
        } else {
            sessionQueue.asyncAfter(deadline: .now() + 0.55) { [weak self] in
                guard let self, let device = self.videoDevice else { return }
                guard !self.focusLockedOnSessionQueue else { return }
                do {
                    try device.lockForConfiguration()
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                    if device.isAutoFocusRangeRestrictionSupported {
                        device.autoFocusRangeRestriction = .near
                    }
                    device.unlockForConfiguration()
                    DispatchQueue.main.async { self.focusState = .tracking }
                } catch { /* ignore */ }
            }
        }
    }

    private func lockFocusAtCurrentLensPosition() {
        sessionQueue.async { self.lockFocusAtCurrentLensPositionOnSessionQueue() }
    }

    private func lockFocusAtCurrentLensPositionOnSessionQueue() {
        guard let device = videoDevice else { return }
        guard device.isFocusModeSupported(.locked) else {
            DispatchQueue.main.async { self.focusState = .tracking }
            return
        }
        do {
            try device.lockForConfiguration()
            let position = device.lensPosition
            device.setFocusModeLocked(lensPosition: position) { [weak self] _ in
                guard let self else { return }
                self.focusLockedOnSessionQueue = true
                DispatchQueue.main.async {
                    self.focusState = .locked
                    self.focusLocked = true
                }
            }
            device.unlockForConfiguration()
        } catch {
            NSLog("[PokeVault] Focus lock failed: \(error)")
        }
    }

    private func unlockFocusToNearContinuous() {
        sessionQueue.async {
            self.focusLockedOnSessionQueue = false
            guard let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isAutoFocusRangeRestrictionSupported {
                    device.autoFocusRangeRestriction = .near
                }
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.focusLocked = false
                    self.focusState = .tracking
                }
            } catch {
                DispatchQueue.main.async { self.focusLocked = false }
            }
        }
    }

    private func installObservers(for device: AVCaptureDevice) {
        if let observer = subjectAreaObserver {
            NotificationCenter.default.removeObserver(observer)
            subjectAreaObserver = nil
        }
        subjectAreaObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceSubjectAreaDidChange,
            object: device,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            self.sessionQueue.async {
                guard !self.focusLockedOnSessionQueue else { return }
                self.pulseAutoFocusOnSessionQueue(
                    devicePoint: self.lastTapDevicePoint,
                    thenLock: false
                )
            }
        }

        adjustingKVO = device.observe(\.isAdjustingFocus, options: [.new]) { [weak self] _, change in
            let adjusting = change.newValue ?? false
            DispatchQueue.main.async {
                guard let self else { return }
                if self.focusLocked { return }
                self.focusState = adjusting ? .adjusting : .tracking
            }
        }
    }

    // MARK: - Torch

    private func setTorchOnSessionQueue(_ on: Bool) {
        guard let device = videoDevice, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if on, device.isTorchModeSupported(.on) {
                try device.setTorchModeOn(level: 0.35)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            NSLog("[PokeVault] Torch failed: \(error)")
            DispatchQueue.main.async {
                self.torchEnabled = false
            }
        }
    }
}

extension CameraCaptureService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image: UIImage?
        if error == nil, let data = photo.fileDataRepresentation() {
            image = UIImage(data: data)
        } else {
            image = nil
        }
        sessionQueue.async {
            let cont = self.photoContinuation
            self.photoContinuation = nil
            cont?.resume(returning: image)
        }
    }
}

// MARK: - Preview

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    var onTapFocus: ((CGPoint, CGSize) -> Void)?

    init(previewLayer: AVCaptureVideoPreviewLayer, onTapFocus: ((CGPoint, CGSize) -> Void)? = nil) {
        self.previewLayer = previewLayer
        self.onTapFocus = onTapFocus
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapFocus: onTapFocus)
    }

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        view.backgroundColor = .black
        view.attach(previewLayer)
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)
        view.isUserInteractionEnabled = true
        context.coordinator.onTapFocus = onTapFocus
        return view
    }

    func updateUIView(_ uiView: PreviewHostView, context: Context) {
        uiView.attach(previewLayer)
        context.coordinator.onTapFocus = onTapFocus
    }

    final class Coordinator: NSObject {
        var onTapFocus: ((CGPoint, CGSize) -> Void)?
        init(onTapFocus: ((CGPoint, CGSize) -> Void)?) {
            self.onTapFocus = onTapFocus
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            onTapFocus?(gesture.location(in: view), view.bounds.size)
        }
    }

    final class PreviewHostView: UIView {
        private weak var hostedLayer: AVCaptureVideoPreviewLayer?

        func attach(_ layer: AVCaptureVideoPreviewLayer) {
            if hostedLayer !== layer {
                hostedLayer?.removeFromSuperlayer()
                self.layer.addSublayer(layer)
                hostedLayer = layer
            }
            layer.frame = bounds
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            hostedLayer?.frame = bounds
        }
    }
}
