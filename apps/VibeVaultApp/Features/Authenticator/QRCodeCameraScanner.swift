import AVFoundation
import Foundation

final class QRCodeCameraScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    enum State: Equatable {
        case idle
        case requestingPermission
        case scanning
        case unavailable(String)
    }

    @Published private(set) var state: State = .idle
    let session = AVCaptureSession()
    var onCode: ((String) -> Void)?
    private let sessionQueue = DispatchQueue(label: "dev.vibevault.qr-camera")
    private var configured = false
    private var deliveredCode = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            state = .requestingPermission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureAndStart() }
                    else { self?.state = .unavailable("Camera access is off.") }
                }
            }
        case .denied, .restricted:
            state = .unavailable("Camera access is off.")
        @unknown default:
            state = .unavailable("Camera is unavailable.")
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureAndStart() {
        deliveredCode = false
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                if !configured { try configureSession(); configured = true }
                if !session.isRunning { session.startRunning() }
                DispatchQueue.main.async { self.state = .scanning }
            } catch {
                DispatchQueue.main.async {
                    self.state = .unavailable("No camera is available.")
                }
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        guard let device = AVCaptureDevice.systemPreferredCamera ?? discovery.devices.first else {
            throw CameraError.unavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.unavailable }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { throw CameraError.unavailable }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !deliveredCode,
              let object = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              object.type == .qr,
              let value = object.stringValue else { return }
        deliveredCode = true
        onCode?(value)
    }

    private enum CameraError: Error { case unavailable }
}
