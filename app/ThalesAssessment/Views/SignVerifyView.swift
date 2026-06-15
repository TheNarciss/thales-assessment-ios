import SwiftUI
import CryptoKit

struct SignVerifyView: View {
    let keypair: P256.Signing.PrivateKey?

    @State private var message: String = "Sign me"
    @State private var rawSignature: Data?
    @State private var originalRaw: Data?
    @State private var derSignature: Data?
    @State private var tampered = false
    @State private var cryptoKitValid: Bool?
    @State private var signing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                screenHeader

                if keypair == nil {
                    emptyState
                } else {
                    activeContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: message) { _, _ in clearSignature() }
        .onChange(of: keypair?.publicKey.rawRepresentation) { _, _ in clearSignature() }
    }

    // MARK: - Sections

    private var screenHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sign & Verify")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("ECDSA P-256 over SHA-256 digest")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("No keypair")
                    .font(.headline)
                Text("Generate one on the Keys tab first.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var activeContent: some View {
        messageSection
        signControl

        if let raw = rawSignature, let der = derSignature {
            signatureSection(raw: raw, der: der)
                .transition(.opacity.combined(with: .move(edge: .top)))

            if let valid = cryptoKitValid {
                verifySection(valid: valid)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            tamperControls
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("MESSAGE")

            TextField("Message to sign", text: $message, axis: .vertical)
                .lineLimit(2...5)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("utf-8 · \(messageByteCount) bytes")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
    }

    private var signControl: some View {
        Button(action: sign) {
            Label(signing ? "Signing…" : "Sign", systemImage: "signature")
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(signing)
    }

    private func signatureSection(raw: Data, der: Data) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("SIGNATURE")
                Spacer()
                if tampered {
                    Label("tampered", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.red)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                HashIdenticon(bytes: raw, size: 88)
                    .id(raw)
                    .opacity(tampered ? 0.4 : 1)
                    .transition(.scale.combined(with: .opacity))

                VStack(alignment: .leading, spacing: 12) {
                    encodingRow(label: "RAW · P1363", bytes: raw)
                    encodingRow(label: "DER · ASN.1", bytes: der)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func encodingRow(label: String, bytes: Data) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Text("· \(bytes.count) bytes")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            Text(Hex.encode(bytes))
                .font(.caption2.monospaced())
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }

    private func verifySection(valid: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: valid ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 36))
                .foregroundStyle(valid ? .green : .red)
                .symbolEffect(.bounce, value: valid)

            VStack(alignment: .leading, spacing: 2) {
                Text(valid ? "Valid signature" : "Invalid signature")
                    .font(.headline)
                    .foregroundStyle(valid ? .green : .red)
                Text(valid
                     ? "Verified locally via CryptoKit"
                     : "CryptoKit rejected the signature")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var tamperControls: some View {
        HStack(spacing: 8) {
            if !tampered {
                Button(action: tamper) {
                    Label("Tamper signature", systemImage: "scribble")
                        .font(.caption.monospaced())
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: reset) {
                    Label("Reset", systemImage: "arrow.uturn.backward")
                        .font(.caption.monospaced())
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }

    private var messageByteCount: Int {
        message.data(using: .utf8)?.count ?? 0
    }

    // MARK: - Actions

    private func clearSignature() {
        withAnimation {
            rawSignature = nil
            originalRaw = nil
            derSignature = nil
            tampered = false
            cryptoKitValid = nil
        }
    }

    private func sign() {
        guard let kp = keypair else { return }
        signing = true
        defer { signing = false }

        let msgBytes = message.data(using: .utf8) ?? Data()
        let digest = SHA256.hash(data: msgBytes)

        do {
            let signature = try kp.signature(for: digest)
            let raw = signature.rawRepresentation
            let der = try DER.encode(rawSignature: raw)

            withAnimation {
                rawSignature = raw
                originalRaw = raw
                derSignature = der
                tampered = false
            }
            runVerify(raw: raw, message: msgBytes, publicKey: kp.publicKey)
        } catch {
            cryptoKitValid = nil
        }
    }

    private func tamper() {
        guard let raw = rawSignature, let kp = keypair else { return }
        var flipped = raw
        flipped[0] ^= 0x01

        withAnimation {
            rawSignature = flipped
            derSignature = try? DER.encode(rawSignature: flipped)
            tampered = true
        }

        let msgBytes = message.data(using: .utf8) ?? Data()
        runVerify(raw: flipped, message: msgBytes, publicKey: kp.publicKey)
    }

    private func reset() {
        guard let original = originalRaw, let kp = keypair else { return }
        withAnimation {
            rawSignature = original
            derSignature = try? DER.encode(rawSignature: original)
            tampered = false
        }

        let msgBytes = message.data(using: .utf8) ?? Data()
        runVerify(raw: original, message: msgBytes, publicKey: kp.publicKey)
    }

    private func runVerify(raw: Data, message: Data, publicKey: P256.Signing.PublicKey) {
        do {
            let sig = try P256.Signing.ECDSASignature(rawRepresentation: raw)
            let digest = SHA256.hash(data: message)
            withAnimation {
                cryptoKitValid = publicKey.isValidSignature(sig, for: digest)
            }
        } catch {
            withAnimation { cryptoKitValid = false }
        }
    }
}
