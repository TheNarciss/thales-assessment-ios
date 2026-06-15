import XCTest
@testable import ThalesAssessment

final class DERTests: XCTestCase {

    // MARK: - Encode

    func testEncodeRejectsWrongRawLength() {
        XCTAssertThrowsError(try DER.encode(rawSignature: Data(count: 63))) { e in
            XCTAssertEqual(e as? DERError, .invalidRawLength)
        }
        XCTAssertThrowsError(try DER.encode(rawSignature: Data(count: 65))) { e in
            XCTAssertEqual(e as? DERError, .invalidRawLength)
        }
    }

    func testEncodeStartsWithSequenceTag() throws {
        let raw = Data(repeating: 0x42, count: 64)
        let der = try DER.encode(rawSignature: raw)
        XCTAssertEqual(der[der.startIndex], 0x30) // SEQUENCE tag
    }

    // MARK: - Roundtrip

    func testRoundtripBasic() throws {
        let raw = Data(repeating: 0x01, count: 64)
        let der = try DER.encode(rawSignature: raw)
        XCTAssertEqual(try DER.decode(derSignature: der), raw)
    }

    func testRoundtripWithHighBitSet() throws {
        // First byte 0xff means high bit set on both r and s → DER prepends 0x00.
        let raw = Data(repeating: 0xff, count: 64)
        let der = try DER.encode(rawSignature: raw)
        XCTAssertEqual(try DER.decode(derSignature: der), raw)
    }

    func testRoundtripWithLeadingZeros() throws {
        // r and s start with zero bytes → DER strips them minimally.
        var raw = Data(count: 64)
        for i in 28..<32 { raw[i] = 0xa5 }
        for i in 60..<64 { raw[i] = 0x5a }
        let der = try DER.encode(rawSignature: raw)
        XCTAssertEqual(try DER.decode(derSignature: der), raw)
    }

    // MARK: - Strict acceptance

    func testDecodeRejectsTrailingBytes() throws {
        var der = try DER.encode(rawSignature: Data(repeating: 0x01, count: 64))
        der.append(0x00)
        XCTAssertThrowsError(try DER.decode(derSignature: der)) { e in
            XCTAssertEqual(e as? DERError, .trailingBytes)
        }
    }

    func testDecodeRejectsLongFormLength() {
        // SEQUENCE with long-form length (0x81 indicates "next byte is length").
        let body = Data([0x02, 0x01, 0x05, 0x02, 0x01, 0x05])
        var malformed = Data([0x30, 0x81, UInt8(body.count)])
        malformed.append(body)
        XCTAssertThrowsError(try DER.decode(derSignature: malformed)) { e in
            XCTAssertEqual(e as? DERError, .longFormLength)
        }
    }

    func testDecodeRejectsNonMinimalInteger() {
        // INTEGER with leading 0x00 followed by a non-high-bit byte (unnecessary padding).
        // SEQUENCE: INTEGER(0x00, 0x05) + INTEGER(0x01)
        // SEQUENCE length = 7: 2 (header of int1) + 2 (content of int1) + 2 (header of int2) + 1 (content of int2)
        let malformed = Data([
            0x30, 0x07,
            0x02, 0x02, 0x00, 0x05,
            0x02, 0x01, 0x01
        ])
        XCTAssertThrowsError(try DER.decode(derSignature: malformed)) { e in
            XCTAssertEqual(e as? DERError, .nonMinimalInteger)
        }
    }

    func testDecodeRejectsNegativeInteger() {
        // INTEGER with high bit set on the first byte = negative.
        // SEQUENCE: INTEGER(0x80) + INTEGER(0x01)
        let malformed = Data([
            0x30, 0x06,
            0x02, 0x01, 0x80,
            0x02, 0x01, 0x01
        ])
        XCTAssertThrowsError(try DER.decode(derSignature: malformed)) { e in
            XCTAssertEqual(e as? DERError, .negativeInteger)
        }
    }

    func testDecodeRejectsWrongOuterTag() {
        // 0x31 = SET (not SEQUENCE)
        let malformed = Data([0x31, 0x06, 0x02, 0x01, 0x05, 0x02, 0x01, 0x05])
        XCTAssertThrowsError(try DER.decode(derSignature: malformed)) { e in
            XCTAssertEqual(e as? DERError, .wrongTag)
        }
    }
}
