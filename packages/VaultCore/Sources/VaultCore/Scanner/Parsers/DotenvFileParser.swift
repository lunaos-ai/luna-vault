import Foundation

/// Parses secret names from a dotenv file (`.env`, `.env.local`, etc.).
public struct DotenvFileParser: SecretFileParser {
    public let filename: String

    public init(filename: String) { self.filename = filename }

    public func parse(content: String) -> [String] {
        DotenvImporter.parse(content).map(\.name)
    }
}

extension ProjectScanner {
    public static func dotenvParsers() -> [SecretFileParser] {
        DotenvDiscovery.filenames.map { DotenvFileParser(filename: $0) }
    }
}
