import Foundation

enum DERError: Error, Equatable {
    case invalidRawLength
    case wrongTag
    case longFormLength
    case nonMinimalInteger
    case negativeInteger
    case emptyInteger
    case integerTooLarge
    case trailingBytes
    case unexpectedEnd
}

/// Strict DER encoder/decoder for P-256 ECDSA signatures. Mirrors
/// `app/frontend/src/lib/der.ts` and `app/backend/encoding.py` — the
/// three implementations share the same acceptance set and any drift
/// would surface in the cross-implementation integration tests.
///
/// Rejects: long-form length encodings (signatures fit in short-form),
/// non-minimal INTEGER encodings (extra leading zero unless needed for
/// sign), negative INTEGERs, and trailing bytes after the SEQUENCE.
enum DER {

    // MARK: - Public API

    /// Convert a raw P1363 P-256 signature (64 bytes: `r || s`) into DER.
    static func encode(rawSignature raw: Data) throws -> Data {
        guard raw.count == 64 else { throw DERError.invalidRawLength }
        let r = encodeInteger(Data(raw.prefix(32)))
        let s = encodeInteger(Data(raw.suffix(32)))
        var content = Data(capacity: r.count + s.count)
        content.append(r)
        content.append(s)
        return tagShortLength(0x30, value: content)
    }

    /// Convert a DER P-256 signature into raw P1363 (64 bytes: `r || s`).
    static func decode(derSignature der: Data) throws -> Data {
        let (seq, afterSeq) = try parseTLV(der, at: 0, expectedTag: 0x30)
        guard afterSeq == der.count else { throw DERError.trailingBytes }

        let (rBytes, afterR) = try parseTLV(seq, at: 0, expectedTag: 0x02)
        let (sBytes, afterS) = try parseTLV(seq, at: afterR, expectedTag: 0x02)
        guard afterS == seq.count else { throw DERError.trailingBytes }

        let r = try decodeScalar(rBytes)
        let s = try decodeScalar(sBytes)

        var out = Data(capacity: 64)
        out.append(r)
        out.append(s)
        return out
    }

    // MARK: - Private helpers

    /// Encode a 32-byte big-endian scalar as a minimal ASN.1 INTEGER.
    private static func encodeInteger(_ scalar: Data) -> Data {
        // Strip leading zero bytes (keep at least one).
        var value = scalar
        while value.count > 1 && value.first == 0 {
            value = Data(value.dropFirst())
        }
        // If high bit is set, prepend 0x00 so the INTEGER stays positive.
        if let first = value.first, first & 0x80 != 0 {
            var padded = Data(capacity: value.count + 1)
            padded.append(0x00)
            padded.append(value)
            value = padded
        }
        return tagShortLength(0x02, value: value)
    }

    private static func tagShortLength(_ tag: UInt8, value: Data) -> Data {
        // Short-form length only: enough for any P-256 signature INTEGER (≤ 33)
        // and any SEQUENCE that contains two of them (≤ 70).
        precondition(value.count < 0x80, "DER short-form only (caller bug)")
        var out = Data(capacity: 2 + value.count)
        out.append(tag)
        out.append(UInt8(value.count))
        out.append(value)
        return out
    }

    /// Parse a Tag-Length-Value at the given offset. Strict short-form length.
    /// Returns the content bytes and the offset of the next byte after the TLV.
    private static func parseTLV(
        _ buf: Data,
        at offset: Int,
        expectedTag: UInt8
    ) throws -> (Data, Int) {
        let base = buf.startIndex
        let end = buf.endIndex
        let i = base + offset
        guard i < end else { throw DERError.unexpectedEnd }
        guard buf[i] == expectedTag else { throw DERError.wrongTag }
        guard i + 1 < end else { throw DERError.unexpectedEnd }
        let lengthByte = buf[i + 1]
        guard lengthByte & 0x80 == 0 else { throw DERError.longFormLength }
        let length = Int(lengthByte)
        let contentStart = i + 2
        let contentEnd = contentStart + length
        guard contentEnd <= end else { throw DERError.unexpectedEnd }
        let content = Data(buf[contentStart..<contentEnd])
        return (content, offset + 2 + length)
    }

    /// Decode an ASN.1 INTEGER's content into a 32-byte fixed-width scalar.
    private static func decodeScalar(_ bytes: Data) throws -> Data {
        guard !bytes.isEmpty else { throw DERError.emptyInteger }

        let firstByte = bytes[bytes.startIndex]

        // Negative INTEGER (two's complement: high bit set means negative).
        guard firstByte & 0x80 == 0 else { throw DERError.negativeInteger }

        // Non-minimal: leading 0x00 followed by a byte whose high bit is NOT
        // set — the zero is then unnecessary padding.
        if bytes.count >= 2 {
            let second = bytes[bytes.startIndex + 1]
            if firstByte == 0 && (second & 0x80) == 0 {
                throw DERError.nonMinimalInteger
            }
        }

        // Strip optional sign padding byte.
        let stripped: Data = firstByte == 0
            ? Data(bytes.dropFirst())
            : bytes

        guard stripped.count <= 32 else { throw DERError.integerTooLarge }

        // Left-pad to 32 bytes (big-endian scalar).
        var out = Data(repeating: 0, count: 32 - stripped.count)
        out.append(stripped)
        return out
    }
}
