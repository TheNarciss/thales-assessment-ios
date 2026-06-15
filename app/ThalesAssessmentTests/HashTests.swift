import XCTest
import CryptoKit
@testable import ThalesAssessment

/// SHA-256 known-answer tests from FIPS 180-4 Appendix A.1. These prove
/// CryptoKit produces what any conforming implementation produces; they
/// are not self-tests.
final class HashTests: XCTestCase {

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return Hex.encode(Data(digest))
    }

    func testEmptyInputKAT() {
        XCTAssertEqual(
            sha256Hex(Data()),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    }

    func testAbcKAT() {
        let bytes = "abc".data(using: .utf8)!
        XCTAssertEqual(
            sha256Hex(bytes),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func test448BitMessageKAT() {
        let input = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        XCTAssertEqual(
            sha256Hex(input.data(using: .utf8)!),
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        )
    }

    func testMillionLettersAKAT() {
        let data = Data(repeating: 0x61, count: 1_000_000) // 1M × 'a'
        XCTAssertEqual(
            sha256Hex(data),
            "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0"
        )
    }

    // MARK: - Byte-exact NFC vs NFD (matches the cross-impl test)

    func testNfcAndNfdProduceDifferentDigests() throws {
        let nfc = try Hex.decode("c3a9")       // NFC é
        let nfd = try Hex.decode("65cc81")     // NFD é
        XCTAssertNotEqual(sha256Hex(nfc), sha256Hex(nfd))
    }
}
