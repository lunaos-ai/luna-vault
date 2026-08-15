import AVFoundation
import AppKit
import SwiftUI

struct LiveQRCodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = QRCodeCameraScanner()
    let onCode: (String) -> Void

    var body: some View {
        ZStack {
            CameraPreview(session: scanner.session)
                .background(Color(nsColor: .black))
            if scanner.state != .scanning { statusView }
            VStack {
                HStack {
                    Text("Scan QR code").font(.headline).foregroundStyle(.white)
                    Spacer()
                    Button("Cancel") { dismiss() }
                }
                Spacer()
                Text("Hold the authenticator QR code in view")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Tokens.Space.md)
                    .padding(.vertical, Tokens.Space.sm)
                    .background(.black.opacity(0.65), in: Capsule())
            }
            .padding(Tokens.Space.lg)
        }
        .frame(width: 640, height: 420)
        .onAppear {
            scanner.onCode = { value in
                onCode(value)
                dismiss()
            }
            scanner.start()
        }
        .onDisappear { scanner.stop() }
    }

    @ViewBuilder
    private var statusView: some View {
        VStack(spacing: Tokens.Space.md) {
            switch scanner.state {
            case .idle, .requestingPermission:
                ProgressView().controlSize(.small)
                Text("Starting camera")
            case .unavailable(let message):
                Image(systemName: "camera.fill").font(.title)
                Text(message).font(.headline)
                Button("Open Camera Settings") { openCameraSettings() }
            case .scanning:
                EmptyView()
            }
        }
        .foregroundStyle(.white)
        .padding(Tokens.Space.xl)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }

    private func openCameraSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.previewLayer.session = session
    }
}

private final class PreviewView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}
