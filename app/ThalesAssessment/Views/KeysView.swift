import SwiftUI
import CryptoKit

private enum KeyFormat {
    case hex
    case pem
}

struct KeysView: View {
    @Binding var keypair: P256.Signing.PrivateKey?
    @State private var revealPrivate = false
    @State private var regenConfirming = false
    @State private var regenTimerTask: Task<Void, Never>?
    @State private var publicFormat: KeyFormat = .hex
    @State private var privateFormat: KeyFormat = .hex
    @State private var showingImport = false

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
        .sheet(isPresented: $showingImport) {
            ImportPEMSheet(onImport: handleImport)
        }
    }

    // MARK: - Sections

    private var screenHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keys")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("ECDSA P-256 · in-memory only")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: { showingImport = true }) {
                Label("Import", systemImage: "square.and.arrow.down")
                    .font(.caption.monospaced())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
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
                Text("Generate a P-256 keypair or import a PKCS#8 PEM via the button above.")
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
        publicKeySection(keypair: kp)
        privateKeySection(keypair: kp)
        regenerateControl
    }

    private func publicKeySection(keypair kp: P256.Signing.PrivateKey) -> some View {
        let bytes = kp.publicKey.x963Representation
        let pem = kp.publicKey.pemRepresentation

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("PUBLIC KEY")
                Spacer()
                formatPicker(selection: $publicFormat)
            }

            HStack(alignment: .top, spacing: 16) {
                HashIdenticon(bytes: bytes, size: 88)
                    .id(bytes)
                    .transition(.scale.combined(with: .opacity))

                Group {
                    if publicFormat == .hex {
                        Text(Hex.encode(bytes))
                            .lineLimit(6)
                    } else {
                        Text(pem)
                            .lineLimit(nil)
                    }
                }
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(publicFormat == .hex
                ? "X9.62 uncompressed · 0x04 || X || Y · \(bytes.count) bytes"
                : "SPKI · PEM")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func privateKeySection(keypair kp: P256.Signing.PrivateKey) -> some View {
        let bytes = kp.rawRepresentation
        let pem = kp.pemRepresentation

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                sectionLabel("PRIVATE KEY")
                Spacer()
                formatPicker(selection: $privateFormat)
                Button(action: { withAnimation { revealPrivate.toggle() } }) {
                    Label(
                        revealPrivate ? "Hide" : "Reveal",
                        systemImage: revealPrivate ? "eye.slash" : "eye"
                    )
                    .font(.caption2.monospaced())
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(revealPrivate ? "Hide private key" : "Reveal private key")
            }

            Group {
                if revealPrivate {
                    if privateFormat == .hex {
                        Text(Hex.encode(bytes))
                            .lineLimit(4)
                    } else {
                        Text(pem)
                            .lineLimit(nil)
                    }
                } else {
                    Text(privateFormat == .hex
                        ? String(repeating: "•", count: 64)
                        : "Tap reveal to display PKCS#8 PEM")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .font(.caption.monospaced())
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)

            Text(privateFormat == .hex
                ? "\(bytes.count) bytes · never leaves the device"
                : "PKCS#8 · PEM · never leaves the device")
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

    private func formatPicker(selection: Binding<KeyFormat>) -> some View {
        Picker("Format", selection: selection) {
            Text("hex").tag(KeyFormat.hex)
            Text("pem").tag(KeyFormat.pem)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 100)
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

    private func handleImport(_ key: P256.Signing.PrivateKey) {
        withAnimation {
            keypair = key
            revealPrivate = false
        }
    }
}

// MARK: - Import sheet

private struct ImportPEMSheet: View {
    let onImport: (P256.Signing.PrivateKey) -> Void
    @State private var text = ""
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Paste a PKCS#8 private key (-----BEGIN PRIVATE KEY-----). The public key is derived from it, so a single paste is enough.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $text)
                        .font(.caption.monospaced())
                        .frame(minHeight: 240)
                        .padding(8)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption.monospaced())
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("ImportError")
                    }
                }
                .padding(20)
            }
            .navigationTitle("Import key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import", action: doImport)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func doImport() {
        do {
            let key = try P256.Signing.PrivateKey(pemRepresentation: text)
            onImport(key)
            dismiss()
        } catch {
            errorMessage = "Invalid PKCS#8 PEM"
        }
    }
}