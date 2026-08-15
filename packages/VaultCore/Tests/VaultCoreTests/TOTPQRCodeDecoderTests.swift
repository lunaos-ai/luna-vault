import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import XCTest
@testable import VaultCore

final class TOTPQRCodeDecoderTests: XCTestCase {
    func test_decodesOtpauthPayloadFromSelectedImage() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil,
                      "Vision QR detection is not reliable on headless CI runners")
        let payload = "otpauth://totp/Example:alice?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        let imageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vv-qr-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: imageURL) }
        try makeQRCode(payload).write(to: imageURL)

        XCTAssertEqual(try TOTPQRCodeDecoder.payloads(in: imageURL), [payload])
    }

    func test_decodesOtpauthPayloadFromImageData() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil,
                      "Vision QR detection is not reliable on headless CI runners")
        let payload = "otpauth://totp/GitHub:test@example.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub"

        XCTAssertEqual(try TOTPQRCodeDecoder.payloads(in: makeQRCode(payload)), [payload])
    }

    func test_rejectsOversizedImageDataBeforeDecoding() {
        let data = Data(repeating: 0, count: 20 * 1_024 * 1_024 + 1)

        XCTAssertThrowsError(try TOTPQRCodeDecoder.payloads(in: data)) { error in
            XCTAssertEqual(error as? TOTPQRCodeError, .imageTooLarge)
        }
    }

    private func makeQRCode(_ value: String) throws -> Data {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        guard let output = filter.outputImage?.transformed(
            by: CGAffineTransform(scaleX: 8, y: 8)
        ), let cgImage = CIContext().createCGImage(output, from: output.extent) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}
