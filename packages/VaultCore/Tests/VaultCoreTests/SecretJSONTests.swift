import XCTest
@testable import VaultCore

final class SecretJSONTests: XCTestCase {
    func test_pretty_print_object_sorts_keys() throws {
        let pretty = try SecretJSON.prettyPrinted(#"{"z":1,"a":true}"#)
        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertTrue(pretty.hasPrefix("{"))
        XCTAssertLessThan(pretty.distance(from: pretty.startIndex, to: pretty.range(of: "\"a\"")!.lowerBound),
                          pretty.distance(from: pretty.startIndex, to: pretty.range(of: "\"z\"")!.lowerBound))
    }

    func test_rejects_malformed_and_fragments() {
        XCTAssertThrowsError(try SecretJSON.prettyPrinted("{not json"))
        XCTAssertThrowsError(try SecretJSON.prettyPrinted(#""just a string""#))
        XCTAssertThrowsError(try SecretJSON.prettyPrinted("42"))
        XCTAssertThrowsError(try SecretJSON.prettyPrinted(""))
    }

    func test_looksLikeObjectOrArray() {
        XCTAssertTrue(SecretJSON.looksLikeObjectOrArray("  {\"k\":\"v\"} "))
        XCTAssertTrue(SecretJSON.looksLikeObjectOrArray("[1,2]"))
        XCTAssertFalse(SecretJSON.looksLikeObjectOrArray("token-value"))
        XCTAssertFalse(SecretJSON.looksLikeObjectOrArray(#""quoted""#))
    }

    func test_masked_summary_counts_keys() {
        XCTAssertEqual(SecretJSON.maskedSummary(#"{"a":1,"b":2}"#), "JSON object · 2 keys")
        XCTAssertEqual(SecretJSON.maskedSummary("[1]"), "JSON array · 1 item")
        XCTAssertEqual(SecretJSON.maskedSummary("nope"), "{…}")
    }

    func test_prepared_text_is_unchanged() throws {
        let prepared = try SecretJSON.prepared(raw: "plain", kind: .text)
        XCTAssertEqual(prepared.value, "plain")
        XCTAssertEqual(prepared.kind, .text)
    }

    func test_prepared_json_pretty_prints() throws {
        let prepared = try SecretJSON.prepared(raw: #"{"b":2,"a":1}"#, kind: .json)
        XCTAssertEqual(prepared.kind, .json)
        XCTAssertEqual(prepared.value, try SecretJSON.prettyPrinted(#"{"a":1,"b":2}"#))
    }

    func test_secret_json_mask_does_not_leak_payload() {
        let secret = Secret(name: "SA", value: #"{"type":"service_account","private_key":"x"}"#, valueKind: .json)
        XCTAssertEqual(secret.maskedValue, "JSON object · 2 keys")
        XCTAssertFalse(secret.maskedValue.contains("private_key"))
    }

    func test_listed_json_secret_masks_empty_value() {
        let secret = Secret(name: "SA", value: "", valueKind: .json)
        XCTAssertEqual(secret.maskedValue, "{…}")
    }

    func test_legacy_secret_json_decodes_as_text() throws {
        let json = """
        {"name":"T","value":"v","createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:00:00Z","mcpAllowed":false,"hasTOTP":false}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let secret = try decoder.decode(Secret.self, from: Data(json.utf8))
        XCTAssertEqual(secret.valueKind, .text)
        XCTAssertEqual(secret.value, "v")
    }
}

final class JSONSecretsImporterTests: XCTestCase {
    func test_flat_string_map_becomes_text_secrets() throws {
        let items = try JSONSecretsImporter.parse(
            #"{"cf_api_token":"tok","STRIPE_KEY":"sk"}"#,
            defaultName: "UNUSED"
        )
        let dict = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })
        XCTAssertEqual(dict["CF_API_TOKEN"], "tok")
        XCTAssertEqual(dict["STRIPE_KEY"], "sk")
        XCTAssertTrue(items.allSatisfy { $0.valueKind == .text })
    }

    func test_nested_object_becomes_one_json_secret() throws {
        let items = try JSONSecretsImporter.parse(
            #"{"type":"service_account","private_key":{"pem":"x"}}"#,
            defaultName: "GOOGLE_SA"
        )
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "GOOGLE_SA")
        XCTAssertEqual(items[0].valueKind, .json)
        XCTAssertTrue(items[0].value.contains("service_account"))
    }

    func test_array_becomes_one_json_secret() throws {
        let items = try JSONSecretsImporter.parse("[{\"id\":1}]", defaultName: "ROWS")
        XCTAssertEqual(items.first?.valueKind, .json)
        XCTAssertEqual(items.first?.name, "ROWS")
    }

    func test_service_account_shaped_json_stays_one_secret() throws {
        let items = try JSONSecretsImporter.parse(
            #"{"type":"service_account","project_id":"x","private_key":"pem"}"#,
            defaultName: "GOOGLE_SA"
        )
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "GOOGLE_SA")
        XCTAssertEqual(items[0].valueKind, .json)
    }

    func test_parse_file_uses_stem_as_name() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("google-sa.json")
        try #"{"type":"service_account","project_id":"x"}"#.write(to: url, atomically: true, encoding: .utf8)
        let items = try JSONSecretsImporter.parseFile(at: url)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "GOOGLE_SA")
        XCTAssertEqual(items[0].valueKind, .json)
    }
}
