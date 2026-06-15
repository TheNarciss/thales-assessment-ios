import XCTest
@testable import ThalesAssessment

final class HexTests: XCTestCase {

    func testEncodeEmpty() {
        XCTAssertEqual(Hex.encode(Data()), "")
    }

    func testEncodeBasic() {
        XCTAssertEqual(Hex.encode(Data([0xab, 0xcd, 0xef])), "abcdef")
    }

    func testEncodePadsSingleNibble() {
        XCTAssertEqual(Hex.encode(Data([0x00, 0x01, 0x0f])), "00010f")
    }

    func testDecodeEmpty() throws {
        XCTAssertEqual(try Hex.decode(""), Data())
    }

    func testDecodeBasic() throws {
        XCTAssertEqual(try Hex.decode("abcdef"), Data([0xab, 0xcd, 0xef]))
    }

    func testDecodeMixedCase() throws {
        XCTAssertEqual(try Hex.decode("aBcDeF"), Data([0xab, 0xcd, 0xef]))
    }

    func testDecodeRejectsOddLength() {
        XCTAssertThrowsError(try Hex.decode("abc")) { error in
            XCTAssertEqual(error as? HexError, .oddLength)
        }
    }

    func testDecodeRejectsInvalidChars() {
        XCTAssertThrowsError(try Hex.decode("zz")) { error in
            XCTAssertEqual(error as? HexError, .invalidCharacter)
        }
    }

    func testRoundtripAllBytes() throws {
        let bytes = Data((0...255).map { UInt8($0) })
        let encoded = Hex.encode(bytes)
        XCTAssertEqual(encoded.count, 512)
        XCTAssertEqual(try Hex.decode(encoded), bytes)
    }
}
