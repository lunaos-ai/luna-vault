import XCTest
@testable import VaultCore

final class DotenvWriterTests: XCTestCase {
    func testQuotesValuesThatNeedIt() {
        XCTAssertEqual(DotenvWriter.line("A", "simple"), "A=simple")
        XCTAssertEqual(DotenvWriter.line("A", "two words"), "A=\"two words\"")
        XCTAssertEqual(DotenvWriter.line("A", "ha#sh"), "A=\"ha#sh\"")
        XCTAssertEqual(DotenvWriter.line("A", ""), "A=\"\"")
        XCTAssertEqual(DotenvWriter.line("A", "a\"b"), "A=\"a\\\"b\"")
        XCTAssertEqual(DotenvWriter.line("A", "a\nb"), "A=\"a\\nb\"")
    }

    func testMergePreservesCommentsUpdatesAndAppends() {
        let existing = "# header\nKEEP=1\nUPDATE=old\n"
        let out = DotenvWriter.merge(existing: existing, updates: [("UPDATE", "new"), ("NEW", "x")])
        XCTAssertTrue(out.contains("# header"))
        XCTAssertTrue(out.contains("KEEP=1"))
        XCTAssertTrue(out.contains("UPDATE=new"))
        XCTAssertFalse(out.contains("UPDATE=old"))
        XCTAssertTrue(out.contains("NEW=x"))
        XCTAssertTrue(out.hasSuffix("\n"))
    }

    func testMergeIntoEmptyFile() {
        let out = DotenvWriter.merge(existing: "", updates: [("A", "1"), ("B", "2")])
        XCTAssertEqual(out, "A=1\nB=2\n")
    }

    func testWriteOverwriteThenMergeOnDisk() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dw-\(UUID().uuidString).env")
        defer { try? FileManager.default.removeItem(at: url) }

        try DotenvWriter.write(secrets: [("API", "k1")], to: url, mode: .overwrite)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "API=k1\n")

        let res = try DotenvWriter.write(secrets: [("API", "k2"), ("DB", "d")], to: url, mode: .merge)
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("API=k2"))
        XCTAssertTrue(text.contains("DB=d"))
        XCTAssertEqual(res.written, ["API", "DB"])

        let perms = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.int16Value, 0o600)
    }
}
