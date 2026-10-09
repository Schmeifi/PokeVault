import AVFoundation
import UIKit
import SwiftUI

/// Live camera session for card scanning (AVFoundation, on-device only).
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

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.pokevault.collection.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?
    private var isConfigured = false

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
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
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
                self.photoContinuation = continuation
                self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    private func configureSessionIfNeeded() async -> Bool {
        if isConfigured { return true }
        return await withCheckedContinuation { continuation in
            sessionQueue.async {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                guard
                    let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                        ?? AVCaptureDevice.default(for: .video),
                    let input = try? AVCaptureDeviceInput(device: device),
                    self.session.canAddInput(input)
                else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.availability = .unavailable("Keine Kamera verfügbar (Simulator?). Nutze Foto-Bibliothek.")
                        continuation.resume(returning: false)
                    }
                    return
                }

                self.session.addInput(input)

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

/// UIKit preview layer hosted in SwiftUI.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
