import Foundation

enum HexError: Error, Equatable {
    case oddLength
    case invalidCharacter
}

/// Hex encode / decode. Mirrors `app/frontend/src/lib/hex.ts`: lowercase
/// output, strict input (even length, `[0-9a-fA-F]` only). The same
/// length-and-charset checks live in the backend Pydantic regex, so
/// malformed hex never reaches the audited crypto primitives.
enum Hex {
    /// Encode bytes as a lowercase hex string (no separators, 2 chars per byte).
    static func encode(_ data: Data) -> String {
        var out = ""
        out.reserveCapacity(data.count * 2)
        for byte in data {
            out.append(String(format: "%02x", byte))
        }
        return out
    }

    /// Decode a hex string into bytes. Throws on odd length or non-hex chars.
    static func decode(_ hex: String) throws -> Data {
        guard hex.count % 2 == 0 else { throw HexError.oddLength }
        var data = Data()
        data.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            let pair = hex[index..<next]
            guard let byte = UInt8(pair, radix: 16) else {
                throw HexError.invalidCharacter
            }
            data.append(byte)
            index = next
        }
        return data
    }
}
