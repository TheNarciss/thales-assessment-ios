import SwiftUI
import CryptoKit

struct KeysView: View {
    @Binding var keypair: P256.Signing.PrivateKey?
    @State private var revealPrivate = false
    @State private var regenConfirming = false
    @State private var regenTimerTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                screenHeader

                if let kp = keypair {
                    activeState(keypair: kp)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Sections

    private var screenHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Keys")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("ECDSA P-256 · in-memory only")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "key.slash")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("No keypair yet")
                    .font(.headline)
                Text("Generate a P-256 keypair to enable signing on the Sign tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(action: generate) {
                Label("Generate keypair", systemImage: "key.fill")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func activeState(keypair kp: P256.Signing.PrivateKey) -> some View {
        let publicKeyBytes = kp.publicKey.x963Representation
        let privateKeyBytes = kp.rawRepresentation

        publicKeySection(bytes: publicKeyBytes)
        privateKeySection(bytes: privateKeyBytes)
        regenerateControl
    }

    private func publicKeySection(bytes: Data) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("PUBLIC KEY")
                Spacer()
                Text("\(bytes.count) bytes")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .top, spacing: 16) {
                HashIdenticon(bytes: bytes, size: 88)
                    .id(bytes)
                    .transition(.scale.combined(with: .opacity))

                Text(Hex.encode(bytes))
                    .font(.caption.monospaced())
                    .lineLimit(6)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("X9.62 uncompressed · 0x04 || X || Y")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func privateKeySection(bytes: Data) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("PRIVATE KEY")
                Spacer()
                Button(action: { withAnimation { revealPrivate.toggle() } }) {
                    Label(
                        revealPrivate ? "Hide" : "Reveal",
                        systemImage: revealPrivate ? "eye.slash" : "eye"
                    )
                    .font(.caption2.monospaced())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if revealPrivate {
                Text(Hex.encode(bytes))
                    .font(.caption.monospaced())
                    .lineLimit(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            } else {
                Text(String(repeating: "•", count: 64))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            Text("\(bytes.count) bytes · never leaves the device")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var regenerateControl: some View {
        HStack {
            Spacer()
            if regenConfirming {
                Button(role: .destructive, action: confirmRegen) {
                    Label("Tap to confirm", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.monospaced())
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: startRegen) {
                    Label("Regenerate", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.monospaced())
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }

    // MARK: - Actions

    private func generate() {
        withAnimation {
            keypair = P256.Signing.PrivateKey()
            revealPrivate = false
        }
    }

    private func startRegen() {
        withAnimation { regenConfirming = true }
        regenTimerTask?.cancel()
        regenTimerTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation { regenConfirming = false }
                }
            }
        }
    }

    private func confirmRegen() {
        regenTimerTask?.cancel()
        withAnimation {
            regenConfirming = false
            keypair = P256.Signing.PrivateKey()
            revealPrivate = false
        }
    }
}
