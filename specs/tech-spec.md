# Technical specification (iOS)

## Stack and scope

Swift 5, SwiftUI, CryptoKit. iOS 17+ deployment target. Xcode
latest. xcodegen for deterministic project generation. XCTest for
tests.

Primitives required by the brief: SHA-256 and ECDSA P-256 (keygen,
sign, verify). Plus a custom strict DER converter to keep the iOS
side at byte parity with the web side.

## Why a native iOS app

The brief asks for a mobile deliverable matching Assignment 1.
CryptoKit provides `P256.Signing.PrivateKey` / `.PublicKey` and
`SHA256` as first-class APIs with the same primitives the brief
requires. Building this in a WebView or hybrid framework would
defeat the purpose of demonstrating native iOS crypto and would
also drag in a network dependency.

The web app is built on a different stack (Web Crypto + Python
`cryptography`). Running the same primitives on both sides shows
that the design is portable to wherever a CryptoKit-equivalent API
exists, rather than coupled to a specific runtime.

## Why no backend on iOS

The web app's backend exists as a second crypto reference for
parity checks (the cross-impl harness in `verification.md` Layer 3).
On iOS, the natural "second reference" would be either:

1. Another mobile platform (Android), which is out of scope for a
   single-app deliverable.
2. The web's backend, accessed over HTTP. This would mean shipping
   a network layer in the iOS app for the sake of a test, which
   contradicts the iOS app's "no network calls" property and would
   force the demo to depend on Docker running on the same host.

Instead, both apps share the same NIST conformance transitively:
the web's backend pins ECDSA P-256 verify against the official
CAVP fixture, the iOS side runs the same algorithm via the same
audited CryptoKit -> CommonCrypto -> CoreCrypto stack that Apple
has validated for FIPS on supported devices, and both
implementations share the FIPS 180-4 SHA-256 KATs (including the
NFC vs NFD byte-exact case). The iOS ECDSA tests focus on
integration properties (roundtrip, tampering, encoding, PEM
import) rather than re-verifying NIST conformance of CryptoKit.

This is a deliberate scope decision documented here, not an
omission.

## Architecture

Single-process SwiftUI app. Three top-level views in a `TabView`
with `indigo` tint:

- `HashView` — text input + live SHA-256 digest in hex + identicon.
- `KeysView` — generate, display, reveal, and import a P-256
  keypair, with a visual identicon derived from the public key.
- `SignVerifyView` — sign the current text with the current
  keypair, show raw + DER signatures, tamper, reset, verify.

The keypair lives in `@State` of the root `ContentView` and is
passed down: `@Binding` to `KeysView` (which mutates it), by value
to `SignVerifyView` (which reads it). All other state is local to
the individual views.

Hashing on input change is debounced 300 ms via a cancellable
`Task`. Signing is synchronous; CryptoKit returns in microseconds
for one signature.

## Stack choices

| Concern | Choice | Reason |
|---|---|---|
| UI | SwiftUI | Native, declarative, matches iOS 17 baseline |
| Hash | CryptoKit `SHA256` | Audited, FIPS-aligned, native |
| Asymmetric | CryptoKit `P256.Signing` | Audited, P-256 native, ergonomic |
| PEM | CryptoKit `pemRepresentation` / `init(pemRepresentation:)` | Native since iOS 14; no custom helper needed unlike the web (Web Crypto exposes no PEM) |
| Hex | Custom `Crypto/Hex.swift` (strict) | Foundation has no public lowercase hex with strict-input parsing |
| Signature encoding | Custom `Crypto/DER.swift` (strict) | CryptoKit produces raw; the DER converter mirrors the web's `der.ts` / `encoding.py` |
| Identicon | Custom `Views/HashIdenticon.swift` | 7×7 grid, horizontally symmetric, deterministic |
| Project generation | xcodegen + `project.yml` | Declarative, no merge conflicts in `project.pbxproj` |
| Tests | XCTest | Standard, runs via `xcodebuild test` |
| CI | GitHub Actions on `macos-15` | Same eval discipline as the web side |

## Private key handling

Keys are generated via `P256.Signing.PrivateKey()`. The private
scalar is exposed via `rawRepresentation` (32 bytes, big-endian).
The public uncompressed form is `publicKey.x963Representation`
(65 bytes, `0x04 ‖ X ‖ Y`, the SEC1 uncompressed encoding from
RFC 5480).

Keys live in `@State` of `ContentView`. No Keychain, no
UserDefaults, no file storage. Backgrounding the app does not
persist them.

Display of the private scalar (hex or PEM) is a deliberate
pedagogical choice and is hidden behind a reveal toggle. A
production UI would never show `d`. The reveal toggle is a
courtesy to the demo intent, not a security control.

## PEM export and import

Both formats are produced and consumed by CryptoKit directly:

```swift
// Export
let pubPem = key.publicKey.pemRepresentation         // SPKI
let privPem = key.pemRepresentation                  // PKCS#8

// Import (throws on malformed or wrong-label PEM)
let pub = try P256.Signing.PublicKey(pemRepresentation: pem)
let priv = try P256.Signing.PrivateKey(pemRepresentation: pem)
```

CryptoKit enforces the label whitelist (PUBLIC KEY for SPKI,
PRIVATE KEY for PKCS#8) and the base64 body validation natively,
so the iOS side does not ship a custom PEM helper, unlike the web
which has its own `lib/pem.ts`. The UI exposes only private-key
import because that is the one users actually need; the
public-only import path is exercised by the unit tests.

The exported PEMs interop with `openssl pkcs8 -topk8` (private)
and `openssl ec -pubin` (public), and by extension with the web
app's `exportPrivateKeyPem` / `exportPublicKeyPem`.

## Signature encoding

CryptoKit produces signatures in raw IEEE P1363 form (`r ‖ s`, 64
bytes for P-256). The custom DER converter in `Crypto/DER.swift`
converts to ASN.1 DER (68 to 72 bytes depending on the high-bit
pattern of `r` and `s`) and back.

Strict DER parsing is enforced on the decode path:

- Long-form length encodings rejected. Signatures fit comfortably
  in short-form (max body length around 70 bytes < 128).
- Non-minimal INTEGER encodings rejected. An extra leading `0x00`
  is only allowed to disambiguate the sign bit, never as padding.
- Negative INTEGERs rejected. First byte must have its high bit
  clear after the optional sign-padding `0x00`.
- Trailing bytes after the SEQUENCE rejected.
- Wrong outer tag (anything other than `0x30`) rejected.
- Empty INTEGER content rejected.

The encoded SEQUENCE always uses short-form length; the encoder
asserts this with a `precondition` since two ~33-byte INTEGERs
never overflow it.

These rules mirror the acceptance set of `app/frontend/src/lib/der.ts`
and `app/backend/encoding.py` on the web side. A drift between
the three implementations would surface in the web's
cross-implementation tests in
`tests/integration/cross_verify.test.mjs`.

ECDSA signature malleability (the existence of a second valid
signature `(r, n - s)` for every `(r, s)`) is not constrained.
Enforcing low-`s` is out of scope and matches what FIPS 186-4
requires of a verifier.

## Visual fingerprint (identicon)

`HashIdenticon` renders a 7×7 grid in a `RoundedRectangle` derived
deterministically from the input bytes:

- First 3 bytes become the foreground colour (one per RGB
  channel).
- For each row, the 4 unique left-half columns (`(gridSize+1)/2`)
  are filled by consulting byte `(row × 4 + col + 3) mod
  bytes.count`; the cell is foreground if `(byte & 0x01) == 1`,
  else `systemGray5`.
- The right half mirrors the left around the centre column.

Same input -> same identicon (deterministic). Flipping a single
bit visibly changes the pattern (which cells flip depends on
which bytes the bit touches).

The identicon is purely a visual aid. It is NOT a cryptographic
commitment to the bytes; many inputs collide on the consulted
bits. It is used the way GitHub identicons and SSH randomart
fingerprints are used: a quick "is this the same thing I saw
before" signal that is faster than comparing 130 hex characters
by eye.

## Error handling

Hex parsing in `Crypto/Hex.swift` throws a typed `HexError` on bad
length (`.oddLength`) or character set (`.invalidCharacter`).

DER parsing in `Crypto/DER.swift` throws a typed `DERError` on
structural issues (9 cases covering each rule in the strict
acceptance set above plus length and end-of-buffer errors).

CryptoKit's `isValidSignature(_:for:)` returns a Bool rather than
throwing; the verify display path treats `false` as "Invalid
signature" with no further detail (CryptoKit deliberately does
not reveal why a signature is invalid, to avoid leaking timing
information).

`P256.Signing.PrivateKey(pemRepresentation:)` and the public-key
initialiser throw on malformed input. The import sheet catches
the error and surfaces "Invalid PKCS#8 PEM" inline. The specific
CryptoKit error string is not displayed because it changes
between iOS versions and is not user-actionable.

No error path on either side logs key material, message content,
or signature bytes.

## Security

Private keys never leave the device process. There is no network
layer in the app: no `URLSession` import, no analytics, no
telemetry, no background tasks.

All cryptographic primitives are calls into CryptoKit. Nothing
rolled by hand, including no custom bit twiddling on signature
components beyond the strict DER converter, which is unit-tested
against the byte output of `P256.Signing.ECDSASignature(rawRepresentation:)`.

`SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` and
`ENABLE_USER_SCRIPT_SANDBOXING: YES` in `project.yml` fail the
build loudly on warnings and sandboxing issues.

## Threat model

Local single-user demo. Same shape as the web threat model with
one fewer trust boundary (no backend, no HTTP).

**In scope.** The application resists:

- Cryptographic incorrectness in CryptoKit. Caught by SHA-256
  KATs from FIPS 180-4 and by the ECDSA roundtrip + tamper +
  wrong-key + DER conversion + PEM import matrix.
- Signature tampering and forgery. Verify hard-fails on any byte
  change to the message, signature, or public key. The tamper
  button demonstrates this in one tap with visual feedback.
- DER encoding confusion. The strict parser rejects every
  BER-only feature and any structural malformation, matching the
  web's acceptance set.

**Out of scope.** The application does not defend against:

- A compromised device (jailbroken iOS, malicious profile,
  hostile iCloud backup). The private key lives in app memory
  and is visible to anything sharing the process.
- A user who screenshots the revealed private key.
- Side-channel attacks (timing, cache, EM). We trust CryptoKit
  to handle these on the key material it manages.
- Quantum adversaries. P-256 is not post-quantum secure. A real
  deployment with longevity would need a PQ migration plan
  (hybrid signatures with ML-DSA for instance).
- Multi-user separation. No authentication, no per-user state
  on device.
- Replay across launches. There is no persistence so this is
  trivially mitigated; in a real app, key continuity would
  need Keychain integration with proper access controls.
- Supply-chain compromise of CryptoKit itself.

## AI workflow

The brief evaluates how AI was used. Same approach as the web
side: one assistant (Claude) drove the project end to end, in
chat mode rather than autonomous mode, with verification before
each commit.

### Constrain the input

A system prompt sets the role (senior iOS engineer) and the
rules: Swift 5, SwiftUI, CryptoKit, no third-party crypto
libraries, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`. The specs in
this folder act as the project's fil rouge.

### Constrain the output

CI gates the loop: `xcodebuild test` on `macos-15` via GitHub
Actions. No warnings allowed (treated as errors at the project
level). Locally, the same command runs before each commit.

### Verify, don't autopilot

The loop:

1. Short turn in chat with the AI.
2. AI proposes a Swift diff.
3. I read it.
4. I run `xcodebuild test` locally.
5. I check the output.
6. Next turn.


### Sourced authority

- FIPS 180-4 Appendix A.1 for SHA-256 KATs.
- RFC 5480 for ECDSA SPKI conventions and the SEC1 uncompressed
  point format.
- ITU-T X.690 for DER encoding rules (the strict acceptance set
  in `DER.swift`).
- Apple CryptoKit documentation for the API surface.

### What was not automated

All primitive choices (curve, hash, raw vs DER, identicon
algorithm, PEM as the import format) were made by hand and
justified here. The identicon palette mapping (first 3 bytes ->
RGB) is a deliberate choice with no security implication; flagged
here so a reader does not mistake it for a cryptographic
commitment.

## Considered and rejected

### A backend client in the iOS app

Early in the build I prototyped a `URLSession`-based client that
would POST to the web app's `/api/verify` for cross-stack
verification at demo time. The earliest README still mentions
that design.

Reverted before final delivery. Reasons:

- It contradicts the "self-contained iOS app" property the
  assignment values.
- It would have made the iOS demo dependent on Docker running on
  the same host, which is brittle for a take-home review.
- The cross-stack agreement signal is already carried by the
  shared NIST / FIPS vectors at test time. Wiring HTTP at
  runtime adds no information.

Listed here as a deliberate scope decision, not a forgotten
feature.