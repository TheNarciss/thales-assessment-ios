import SwiftUI

/// Visual fingerprint for any byte sequence (hash, public key, signature).
///
/// Produces a deterministic 7x7 grid with horizontal symmetry. Same bytes
/// always produce the same identicon. Flipping a single bit visibly changes
/// the pattern.
///
/// Same principle as GitHub identicons, SSH randomart, and Ethereum Blockies:
/// humans recognize geometric patterns far faster than they compare hex
/// strings, which makes this a practical comparison aid in addition to a
/// pleasant visual.
struct HashIdenticon: View {
    let bytes: Data
    var size: CGFloat = 88
    private let gridSize: Int = 7

    var body: some View {
        VStack(spacing: 1) {
            ForEach(0..<gridSize, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<gridSize, id: \.self) { col in
                        Rectangle()
                            .fill(cellColor(row: row, col: col))
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var foreground: Color {
        let arr = Array(bytes)
        guard arr.count >= 3 else { return .accentColor }
        return Color(
            red: Double(arr[0]) / 255,
            green: Double(arr[1]) / 255,
            blue: Double(arr[2]) / 255
        )
    }

    private func cellColor(row: Int, col: Int) -> Color {
        let arr = Array(bytes)
        guard arr.count >= 4 else { return Color(.systemGray5) }

        // Mirror left-right around the center column for a natural symmetric
        // pattern (each row needs only ceil(gridSize/2) unique cells).
        let halfCols = (gridSize + 1) / 2
        let mirroredCol = col < halfCols ? col : (gridSize - 1 - col)

        // Skip first 3 bytes (they're used for the foreground color)
        let byteIndex = (row * halfCols + mirroredCol + 3) % arr.count
        let filled = (arr[byteIndex] & 0x01) == 1

        return filled ? foreground : Color(.systemGray5)
    }
}

#Preview {
    VStack(spacing: 16) {
        HashIdenticon(
            bytes: Data([0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78, 0x9a,
                         0xbc, 0xde, 0xf0, 0x11, 0x22, 0x33, 0x44, 0x55]),
            size: 88
        )
        HashIdenticon(
            bytes: Data((0..<32).map { UInt8($0 &* 7) }),
            size: 88
        )
    }
    .padding()
}
