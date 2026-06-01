import AVFoundation
import Combine
import Foundation

/// Manages a camera capture session for the mirror preview.
///
/// The class is intentionally **not** `@MainActor`: all `AVCaptureSession`
/// work happens on a dedicated serial queue (per Apple's guidance), and only
/// the published `status` is bounced back to the main thread for SwiftUI.
///
/// The `previewLayer` is owned here and lives for the lifetime of the service.
/// SwiftUI hosts this single, persistent layer rather than recreating one each
/// time the mirror view appears - recreating the layer was what left the
/// preview blank after switching tabs.
final class CameraService: ObservableObject {
    enum Status: Equatable {
        case stopped       // not running; waiting for the user to enable it
        case starting      // configuring / awaiting permission
        case running
        case denied
        case unavailable
    }

    @Published private(set) var status: Status = .stopped

    let session = AVCaptureSession()
    let previewLayer: AVCaptureVideoPreviewLayer

    private let sessionQueue = DispatchQueue(label: "com.pratik.notchify.camera")
    // Touched only on `sessionQueue`.
    private var isConfigured = false

    /// Whether the preview is flipped to read like a real mirror.
    var mirrorFlip = true {
        didSet { applyMirroring() }
    }

    init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
    }

    /// Whether camera permission has already been granted, so the UI can tell
    /// the user whether tapping will trigger a system prompt.
    var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    /// Begin previewing. Requests permission on first use. Safe to call again
    /// after `stop()` - the session is reused and simply restarted.
    func start() {
        setStatus(.starting)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configureAndRun()
                } else {
                    self.setStatus(.denied)
                }
            }
        case .denied, .restricted:
            setStatus(.denied)
        @unknown default:
            setStatus(.denied)
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.setStatus(.stopped)
        }
    }

    private func configureAndRun() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                guard let device = AVCaptureDevice.default(for: .video),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    self.setStatus(.unavailable)
                    return
                }
                self.session.addInput(input)
                self.session.commitConfiguration()
                self.isConfigured = true
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
            self.applyMirroring()
            self.setStatus(.running)
        }
    }

    /// Flip the preview so it reads like a real mirror, done at the capture
    /// connection so it survives view recreation.
    private func applyMirroring() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let connection = self.previewLayer.connection,
                  connection.isVideoMirroringSupported else { return }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = self.mirrorFlip
        }
    }

    private func setStatus(_ newStatus: Status) {
        DispatchQueue.main.async { [weak self] in
            self?.status = newStatus
        }
    }
}
