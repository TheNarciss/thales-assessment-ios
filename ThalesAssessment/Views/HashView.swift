import SwiftUI
import CryptoKit

struct HashView: View {
    @State private var input: String = "This is Thales's hash demo"
    @State private var digestBytes: Data?
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                screenHeader
                inputSection

                if let digest = digestBytes {
                    outputSection(digest: digest)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { compute() }
    }

    // MARK: - Sections

    private var screenHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hash")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("SHA-256 · UTF-8 input")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("INPUT")

            TextField(
                "Anything — UTF-8 encoded to bytes",
                text: $input,
                axis: .vertical
            )
            .lineLimit(3...6)
            .font(.system(.body, design: .monospaced))
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onChange(of: input) { _, _ in scheduleHash() }

            Text("utf-8 · \(byteCount) bytes")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
    }

    private func outputSection(digest: Data) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("SHA-256")
                Spacer()
                Text("32 bytes")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .top, spacing: 16) {
                HashIdenticon(bytes: digest, size: 88)
                    .accessibilityLabel("Visual fingerprint of the hash")
                    .id(digest)
                    .transition(.scale.combined(with: .opacity))

                Text(Hex.encode(digest))
                    .font(.caption.monospaced())
                    .lineLimit(8)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }

    private var byteCount: Int {
        input.data(using: .utf8)?.count ?? 0
    }

    private func scheduleHash() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            compute()
        }
    }

    private func compute() {
        let bytes = input.data(using: .utf8) ?? Data()
        let digest = SHA256.hash(data: bytes)
        withAnimation(.easeInOut(duration: 0.2)) {
            digestBytes = Data(digest)
        }
    }
}
