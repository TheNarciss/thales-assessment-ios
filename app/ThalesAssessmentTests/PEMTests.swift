import XCTest
import CryptoKit
@testable import ThalesAssessment

/// PEM export and import round-trip tests against CryptoKit's
/// `pemRepresentation` API. CryptoKit handles strict parsing (footer
/// match, label whitelist, base64 body validation) natively, so no
/// custom PEM helper is needed on the iOS side — unlike the web app
/// which has its own `lib/pem.ts` because Web Crypto exposes no PEM.
///
/// The PKCS#8 (private) and SPKI (public) formats produced here
/// round-trip with `openssl pkcs8 -topk8` and `openssl ec -pubin`
/// respectively, which gives free interop with the web app's
/// `exportPrivateKeyPem` / `exportPublicKeyPem`.
final class PEMTests: XCTestCase {

    func testPrivateKeyPemRoundTripPreservesRawRepresentation() throws {
        let original = P256.Signing.PrivateKey()
        let pem = original.pemRepresentation
        let imported = try P256.Signing.PrivateKey(pemRepresentation: pem)
        XCTAssertEqual(imported.rawRepresentation, original.rawRepresentation)
    }

    func testPublicKeyPemRoundTripPreservesX963Representation() throws {
        let key = P256.Signing.PrivateKey()
        let pem = key.publicKey.pemRepresentation
        let imported = try P256.Signing.PublicKey(pemRepresentation: pem)
        XCTAssertEqual(
            imported.x963Representation,
            key.publicKey.x963Representation
        )
    }

    func testImportedPrivateKeyDerivesMatchingPublicKey() throws {
        let original = P256.Signing.PrivateKey()
        let pem = original.pemRepresentation
        let imported = try P256.Signing.PrivateKey(pemRepresentation: pem)
        XCTAssertEqual(
            imported.publicKey.x963Representation,
            original.publicKey.x963Representation
        )
    }

    func testSignWithImportedKeyVerifiesWithOriginalPublicKey() throws {
        let original = P256.Signing.PrivateKey()
        let pem = original.pemRepresentation
        let imported = try P256.Signing.PrivateKey(pemRepresentation: pem)

        let digest = SHA256.hash(data: "hello world".data(using: .utf8)!)
        let signature = try imported.signature(for: digest)
        XCTAssertTrue(original.publicKey.isValidSignature(signature, for: digest))
    }

    func testSignWithOriginalKeyVerifiesWithImportedPublicKey() throws {
        let original = P256.Signing.PrivateKey()
        let pubPem = original.publicKey.pemRepresentation
        let importedPub = try P256.Signing.PublicKey(pemRepresentation: pubPem)

        let digest = SHA256.hash(data: "hello world".data(using: .utf8)!)
        let signature = try original.signature(for: digest)
        XCTAssertTrue(importedPub.isValidSignature(signature, for: digest))
    }

    func testImportPrivateKeyRejectsPublicKeyPem() throws {
        let key = P256.Signing.PrivateKey()
        let pubPem = key.publicKey.pemRepresentation
        XCTAssertThrowsError(
            try P256.Signing.PrivateKey(pemRepresentation: pubPem)
        )
    }

    func testImportPublicKeyRejectsPrivateKeyPem() throws {
        let key = P256.Signing.PrivateKey()
        let privPem = key.pemRepresentation
        XCTAssertThrowsError(
            try P256.Signing.PublicKey(pemRepresentation: privPem)
        )
    }

    func testImportPrivateKeyRejectsMalformedPem() throws {
        XCTAssertThrowsError(
            try P256.Signing.PrivateKey(pemRepresentation: "not a pem")
        )
    }
}