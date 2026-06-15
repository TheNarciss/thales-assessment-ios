import XCTest
import CryptoKit
@testable import ThalesAssessment

/// ECDSA P-256 sign / verify roundtrips against CryptoKit. The KAT
/// validation against NIST CAVP vectors lives on the backend Python
/// side; CryptoKit's verify path is exercised here through the
/// cross-implementation path (a signature produced by CryptoKit must
/// also verify on the FastAPI backend — see the integration test in
/// the web subproject).
final class ECDSATests: XCTestCase {

    func testSignVerifyRoundtrip() throws {
        let key = P256.Signing.PrivateKey()
        let message = "test message".data(using: .utf8)!
        let digest = SHA256.hash(data: message)

        let signature = try key.signature(for: digest)
        XCTAssertTrue(key.publicKey.isValidSignature(signature, for: digest))
    }

    func testRawSignatureIs64Bytes() throws {
        let key = P256.Signing.PrivateKey()
        let digest = SHA256.hash(data: "test".data(using: .utf8)!)
        let signature = try key.signature(for: digest)
        XCTAssertEqual(signature.rawRepresentation.count, 64)
    }

    func testTamperedMessageRejected() throws {
        let key = P256.Signing.PrivateKey()
        let message = "test message".data(using: .utf8)!
        var tampered = message
        tampered[0] ^= 0x01

        let signature = try key.signature(for: SHA256.hash(data: message))
        XCTAssertFalse(
            key.publicKey.isValidSignature(
                signature,
                for: SHA256.hash(data: tampered)
            )
        )
    }

    func testWrongKeyRejected() throws {
        let keyA = P256.Signing.PrivateKey()
        let keyB = P256.Signing.PrivateKey()
        let digest = SHA256.hash(data: "test".data(using: .utf8)!)

        let signature = try keyA.signature(for: digest)
        XCTAssertFalse(keyB.publicKey.isValidSignature(signature, for: digest))
    }

    func testPublicKeyX963IsSEC1Uncompressed() throws {
        // SEC1 uncompressed point: 0x04 || X (32 bytes) || Y (32 bytes) = 65 bytes
        let key = P256.Signing.PrivateKey()
        let pub = key.publicKey.x963Representation
        XCTAssertEqual(pub.count, 65)
        XCTAssertEqual(pub[pub.startIndex], 0x04)
    }

    func testRawSignatureRoundtripsThroughDER() throws {
        let key = P256.Signing.PrivateKey()
        let digest = SHA256.hash(data: "test".data(using: .utf8)!)
        let raw = try key.signature(for: digest).rawRepresentation

        let der = try DER.encode(rawSignature: raw)
        let back = try DER.decode(derSignature: der)
        XCTAssertEqual(back, raw)

        // The re-derived signature must still verify with CryptoKit.
        let rebuilt = try P256.Signing.ECDSASignature(rawRepresentation: back)
        XCTAssertTrue(key.publicKey.isValidSignature(rebuilt, for: digest))
    }
}
