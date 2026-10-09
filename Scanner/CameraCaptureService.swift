import AVFoundation
import UIKit
import SwiftUI

/// Live camera session for close-up card scanning (AVFoundation, on-device only).
///
/// Device policy (back camera):
/// 1. Prefer `builtInWideAngleCamera` — sharpest for collector-number OCR at short distance.
/// 2. Avoid ultra-wide / auto-macro soft focus: if a virtual dual/triple device is used as fallback,
///    lock constituent switching to the wide lens only.
/// 3. Continuous autofocus + `.near` range restriction when supported; tap-to-focus on preview.
final class CameraCaptureService: NSObject, ObservableObject {
    enum CameraAvailability: Equatable {
        case unknown
        case ready
        case denied
        case restricted
        case unavailable(String)
    }

    @Published private(set) var availability: CameraAvailability = .unknown
    @Published private(set) var isSessionRunning = false
    /// Human-readable device choice for debugging / Settings note.
    @Published private(set) var activeDeviceDescription: String = ""

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.pokevault.collection.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?
    private var isConfigured = false
    private var videoDevice: AVCaptureDevice?
    private var subjectAreaObserver: NSObjectProtocol?

    @MainActor
    func startIfPossible() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                availability = .denied
                return
            }
        case .denied:
            availability = .denied
            return
        case .restricted:
            availability = .restricted
            return
        @unknown default:
            availability = .unavailable("Kamerastatus unbekannt.")
            return
        }

        let configured = await configureSessionIfNeeded()
        guard configured else { return }
        availability = .ready
        await startSession()
        // Bias focus toward bottom collector-number strip after warm-up.
        focus(atNormalized: CGPoint(x: 0.5, y: 0.78), lockBriefly: false)
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if let observer = self.subjectAreaObserver {
                NotificationCenter.default.removeObserver(observer)
                self.subjectAreaObserver = nil
            }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    /// Tap-to-focus / exposure. `point` in preview view coordinates; `viewSize` = preview bounds.
    func focus(at viewPoint: CGPoint, in viewSize: CGSize) {
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        // AVFoundation focus point: (0,0) top-left of unrotated landscape buffer for back camera
        // with .resizeAspectFill preview — map UIKit point into 0…1 device space.
        let nx = min(1, max(0, viewPoint.x / viewSize.width))
        let ny = min(1, max(0, viewPoint.y / viewSize.height))
        focus(atNormalized: CGPoint(x: nx, y: ny), lockBriefly: true)
    }

    /// Normalized 0…1 in preview space (y grows downward). Bottom ~0.75–0.9 = number strip.
    func focus(atNormalized point: CGPoint, lockBriefly: Bool) {
        sessionQueue.async { [weak self] in
            self?.applyFocusAndExposure(normalizedPreviewPoint: point, lockBriefly: lockBriefly)
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
                // Snap focus once more on number ROI before shutter.
                self.applyFocusAndExposure(
                    normalizedPreviewPoint: CGPoint(x: 0.5, y: 0.82),
                    lockBriefly: false
                )
                self.photoContinuation = continuation
                self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    // MARK: - Configure

    private func configureSessionIfNeeded() async -> Bool {
        if isConfigured { return true }
        return await withCheckedContinuation { continuation in
            sessionQueue.async {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                guard let device = Self.selectBackCameraForCloseUpOCR() else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.availability = .unavailable("Keine Kamera verfügbar (Simulator?). Nutze Foto-Bibliothek.")
                        continuation.resume(returning: false)
                    }
                    return
                }

                do {
                    try Self.configureDeviceForCloseUp(device)
                } catch {
                    NSLog("[PokeVault] Camera device configure warning: \(error)")
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
                self.session.commitConfiguration()
                self.isConfigured = true

                let desc = Self.describe(device)
                NSLog("[PokeVault] Scanner camera: \(desc)")
                DispatchQueue.main.async {
                    self.activeDeviceDescription = desc
                }

                self.installSubjectAreaObserver(for: device)
                continuation.resume(returning: true)
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

    // MARK: - Device selection

    /// Prefer dedicated wide-angle (not ultra-wide). Virtual multi-cam is fallback with wide locked.
    static func selectBackCameraForCloseUpOCR() -> AVCaptureDevice? {
        // 1) Explicit wide — best default for short-distance card OCR.
        if let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return wide
        }

        // 2) Virtual devices (may auto-macro onto ultra-wide — we lock to wide when configuring).
        let virtualTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: virtualTypes,
            mediaType: .video,
            position: .back
        )
        if let virtual = discovery.devices.first {
            return virtual
        }

        return AVCaptureDevice.default(for: .video)
    }

    static func configureDeviceForCloseUp(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        // Prevent soft ultra-wide auto-macro on virtual devices (iPhone 13+).
        if device.isVirtualDevice,
           device.activePrimaryConstituentDeviceSwitchingBehavior != .unsupported {
            let wide = device.constituentDevices.first(where: {
                $0.deviceType == .builtInWideAngleCamera
            })
            if let wide {
                device.setPrimaryConstituentDeviceSwitchingBehavior(
                    .locked,
                    restrictedSwitchingBehaviorAllowedDevices: [wide]
                )
            }
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
            device.isSmoothAutoFocusEnabled = true
        }

        device.isSubjectAreaChangeMonitoringEnabled = true

        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }

        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }

        // Slightly higher sharpening / avoid video stabilization soft path — photo preset already.
        if device.isLowLightBoostSupported {
            device.automaticallyEnablesLowLightBoostWhenAvailable = true
        }
    }

    static func describe(_ device: AVCaptureDevice) -> String {
        var parts = [device.localizedName, device.deviceType.rawValue]
        if device.isVirtualDevice {
            let lenses = device.constituentDevices.map(\.deviceType.rawValue).joined(separator: "+")
            parts.append("virtual[\(lenses)]")
            parts.append("switch=\(String(describing: device.activePrimaryConstituentDeviceSwitchingBehavior))")
        }
        if device.isAutoFocusRangeRestrictionSupported {
            parts.append("AFRange=near")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Focus

    private func installSubjectAreaObserver(for device: AVCaptureDevice) {
        if let observer = subjectAreaObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        subjectAreaObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceSubjectAreaDidChange,
            object: device,
            queue: nil
        ) { [weak self] _ in
            self?.sessionQueue.async {
                // Re-engage continuous AF near the number strip after subject change.
                self?.applyFocusAndExposure(
                    normalizedPreviewPoint: CGPoint(x: 0.5, y: 0.78),
                    lockBriefly: false
                )
            }
        }
    }

    private func applyFocusAndExposure(normalizedPreviewPoint: CGPoint, lockBriefly: Bool) {
        guard let device = videoDevice else { return }
        // Convert portrait preview (x right, y down) → AVFoundation point of interest
        // for back camera (landscape sensor): typically (y, 1-x) when video is rotated 90°.
        let poi = CGPoint(
            x: min(1, max(0, normalizedPreviewPoint.y)),
            y: min(1, max(0, 1 - normalizedPreviewPoint.x))
        )

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = poi
                if lockBriefly, device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                } else if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = poi
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
            }
        } catch {
            NSLog("[PokeVault] Focus configure failed: \(error)")
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

/// UIKit preview with tap-to-focus.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var onTapFocus: ((CGPoint, CGSize) -> Void)?

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        view.isUserInteractionEnabled = true
        context.coordinator.onTapFocus = onTapFocus
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.session = session
        context.coordinator.onTapFocus = onTapFocus
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        var onTapFocus: ((CGPoint, CGSize) -> Void)?

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let point = gesture.location(in: view)
            onTapFocus?(point, view.bounds.size)
        }
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
        }
    }
}
