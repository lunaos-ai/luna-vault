#if canImport(FoundationNetworking)
@_exported import FoundationNetworking
#endif
import Foundation

extension URLSession {
    func vvData(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        #if os(Linux) || os(Windows)
        try await withCheckedThrowingContinuation { continuation in
            dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, let response = response as? HTTPURLResponse else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                continuation.resume(returning: (data, response))
            }.resume()
        }
        #else
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
        #endif
    }
}
