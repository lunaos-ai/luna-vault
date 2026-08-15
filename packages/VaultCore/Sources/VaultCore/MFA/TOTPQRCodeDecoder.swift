import Foundation
import Vision

public enum TOTPQRCodeError: Error, Equatable, CustomStringConvertible {
    case imageTooLarge
    case noQRCode
    case invalidPayload

    public var description: String {
        switch self {
        case .imageTooLarge: return "QR image is too large"
        case .noQRCode: return "no QR code found in the image"
        case .invalidPayload: return "QR code does not contain a valid authenticator setup"
        }
    }
}

public enum TOTPQRCodeDecoder {
    public static func payloads(in imageURL: URL) throws -> [String] {
        let values = try imageURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw TOTPQRCodeError.noQRCode }
        guard (values.fileSize ?? 0) <= 20 * 1_024 * 1_024 else {
            throw TOTPQRCodeError.imageTooLarge
        }
        let request = barcodeRequest()
        try VNImageRequestHandler(url: imageURL).perform([request])
        return try validatedPayloads(request.results)
    }

    public static func payloads(in imageData: Data) throws -> [String] {
        guard imageData.count <= 20 * 1_024 * 1_024 else {
            throw TOTPQRCodeError.imageTooLarge
        }
        let request = barcodeRequest()
        try VNImageRequestHandler(data: imageData).perform([request])
        return try validatedPayloads(request.results)
    }

    private static func barcodeRequest() -> VNDetectBarcodesRequest {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        return request
    }

    private static func validatedPayloads(
        _ results: [VNBarcodeObservation]?
    ) throws -> [String] {
        let payloads = (results ?? []).compactMap(\.payloadStringValue)
        guard !payloads.isEmpty else { throw TOTPQRCodeError.noQRCode }
        for payload in payloads {
            guard payload.utf8.count <= 16_384 else { throw TOTPQRCodeError.invalidPayload }
            do { _ = try TOTPGenerator.account(from: payload) }
            catch { throw TOTPQRCodeError.invalidPayload }
        }
        return payloads
    }
}
