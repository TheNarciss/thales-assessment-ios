# Requirements (iOS)

## Scope
Native iOS application demonstrating SHA-256 hashing and ECDSA P-256
sign/verify operations. Single user, no persistence, no network. iOS
mirror of the web app (Assignment 1) on the Swift / SwiftUI /
CryptoKit stack.

## Functional requirements

### FR-1 — Hash plain text with SHA-256
On the Hash tab, the user enters arbitrary text in a multi-line
field. The application UTF-8 encodes the text exactly as the field
provides it (no normalisation, no trimming, no BOM handling) and
computes its SHA-256 digest via CryptoKit, displayed as lowercase
hex alongside a 7×7 identicon derived from the digest.
Recomputation is debounced 300 ms on input change.

Acceptance:
- Empty input -> `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
- `"abc"` -> `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`.
- Two bytes `0xc3 0xa9` (NFC `é`) and three bytes `0x65 0xcc 0x81`
  (NFD `é`) produce different digests. `HashTests.swift` pins this
  byte-exact behaviour and the identical test runs on the web side.
- Output is exactly 64 lowercase hex characters.
- The byte length appears under the textfield (`utf-8 · N bytes`).

### FR-2 — Generate an ECDSA P-256 keypair
On the Keys tab, a button generates a fresh keypair via
`P256.Signing.PrivateKey()`. Both keys can be displayed in two
formats via a per-row segmented toggle (`hex / pem`).

- Public key (hex): `x963Representation` (`0x04 ‖ X ‖ Y`), 65 bytes /
  130 hex characters.
- Public key (pem): SPKI `-----BEGIN PUBLIC KEY-----` block.
- Private key (hex): `rawRepresentation`, 32 bytes / 64 hex
  characters. Hidden behind a reveal toggle by default.
- Private key (pem): PKCS#8 `-----BEGIN PRIVATE KEY-----` block.
  Same reveal gate as the hex form.

The public-key view shows a 7×7 identicon to its left.
Regenerating requires a second tap within a 3-second confirmation
window.

Acceptance:
- Public key hex starts with `04` and has length 130.
- Private key scalar has length 64.
- Two consecutive generations produce different keypairs with
  overwhelming probability.
- Exported PEMs round-trip through CryptoKit's
  `init(pemRepresentation:)` for both PKCS#8 (private) and SPKI
  (public) formats. Covered in `PEMTests.swift`.

### FR-3 — Sign a message
On the Sign tab, with a keypair loaded, the user signs the current
text input. The signature is displayed in two encodings
simultaneously, both in hex.

- Raw (IEEE P1363, `signature.rawRepresentation`): 128 hex
  characters (64 bytes).
- DER (ASN.1, custom `Crypto/DER.swift`): 136 to 144 hex characters,
  parses as `SEQUENCE { INTEGER r, INTEGER s }`.

A 7×7 identicon derived from the raw signature accompanies the hex
display.

Acceptance:
- A `Tamper signature` button flips byte 0 of the raw signature and
  re-derives the DER form. Both copies update with a `tampered`
  badge; the identicon dims to give visual feedback.
- A `Reset` button restores the original signature byte-for-byte.

### FR-4 — Verify the signature
After signing, the application verifies the signature it just
produced via `publicKey.isValidSignature(_:for:)` and displays the
result as a green check (`Valid signature`) or red cross
(`Invalid signature`) with a one-line caption.

Acceptance:
- A freshly produced signature verifies as valid.
- A tampered signature (via FR-3) verifies as invalid.
- Editing the message after signing clears the prior signature
  rather than displaying a stale verdict.

### FR-5 — Visual fingerprint (identicon)
A 7×7 grid identicon, derived deterministically from the first
bytes of any byte sequence (digest, public key, raw signature), is
rendered alongside the hex display. The grid is horizontally
symmetric (mirrored around the centre column). Same input produces
the same identicon; flipping a single bit in the input visibly
changes the pattern.

Acceptance:
- A new keypair changes the public-key identicon and the
  signature-time identicon.
- A re-rendered identicon for the same bytes is byte-for-byte
  identical.
- The identicon foreground colour is derived from the first 3
  bytes of the input (one per RGB channel).

### FR-6 — Import keys from PEM
On the Keys tab, an Import action opens a sheet with a textfield
into which the user pastes a PKCS#8 `-----BEGIN PRIVATE KEY-----`
block. The public counterpart is derived from the imported private
key, so a single paste restores a full keypair.

Acceptance:
- Importing a PKCS#8 PEM that was just exported by the application
  restores both the private scalar (raw representation matches
  byte-for-byte) and the matching public key (X9.62 representation
  matches).
- Signatures produced by the imported key verify under the original
  public key, and vice versa.
- Importing a PEM with the wrong label (a `PUBLIC KEY` block passed
  to the private-key import path) is rejected by CryptoKit; the
  sheet surfaces an inline error and the in-memory keypair is not
  mutated.
- Importing a malformed PEM (non-PEM string, missing footer, etc.)
  is rejected by CryptoKit with the same inline error path.
- The textfield is empty when the sheet opens and the sheet
  dismisses on successful import.

## Non-functional requirements

### NFR-1 — Builds and runs
After `xcodegen generate`, the project builds and runs on iOS
Simulator 17+ via Xcode or `xcodebuild`. Tested locally on iPhone
17 running iOS Simulator 26.5.

### NFR-2 — Security hygiene
- Private keys live in `@State` memory of `ContentView` only. No
  Keychain, no UserDefaults, no file storage. Reloading the view
  discards them.
- All cryptographic primitives go through CryptoKit (audited,
  Apple-shipped, FIPS-aligned on supported devices).
- No network calls. `URLSession` is not linked at runtime.
- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` in `project.yml` so any
  warning fails the build.
- `ENABLE_USER_SCRIPT_SANDBOXING: YES` on the build process.

### NFR-3 — Tests pass
`xcodebuild -scheme ThalesAssessment test` exits zero. 38 tests
across Hex (9), DER (10), SHA-256 KAT (5), ECDSA roundtrip /
tamper / wrong-key (6), and PEM round-trip / wrong-label (8). CI
on `macos-15` runs the same suite on every push to `main`.

## Out of scope
- Backend integration / network calls. The mobile assignment is
  self-contained on purpose; the rationale is in `tech-spec.md`.
- Keychain storage. The demo deliberately keeps keys in process
  memory to mirror the web app's "no persistence" property.
- Curves other than P-256; hash algorithms other than SHA-256.
- NIST CAVP vectors for ECDSA on iOS. The web side runs CAVP
  against the same algorithm via `cryptography`; the iOS side
  relies on CryptoKit's audited implementation. Rationale in
  `tech-spec.md`.
- Signature malleability constraints beyond what FIPS 186-4
  requires of a verifier (low-`s` is not enforced).
- Universal Links, AirDrop, Share Sheet integration.
- Identicon snapshot regression tests.