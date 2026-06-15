# Verification (iOS)

Correctness rests on two test layers. Layer 3 (cross-implementation
at runtime) is not applicable because the iOS app is a single-stack
deliverable; see `tech-spec.md` for the rationale. The
cross-implementation parity is instead carried at fixture level:
both stacks pin the same FIPS 180-4 SHA-256 KATs and rely on a
NIST CAVP-conformant ECDSA P-256 implementation underneath
(`cryptography` on the web backend, CryptoKit on iOS).

## Layer 1 — Known-answer tests

### SHA-256 (FIPS 180-4 Appendix A.1)

Vectors covered in `HashTests.swift`:

| Input | Expected digest (hex) |
|---|---|
| `""` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `"abc"` | `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad` |
| `"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"` | `248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1` |
| 1 000 000 × `'a'` | `cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0` |

Plus a NFC-vs-NFD differentiation test
(`testNfcAndNfdProduceDifferentDigests`): the 2 bytes `0xc3 0xa9`
and the 3 bytes `0x65 0xcc 0x81` (both rendering as `é`) produce
different digests. The identical test runs on the web side; any
hidden normalisation in either implementation would surface as
disagreement.

### ECDSA P-256

No NIST CAVP fixture parsed on the iOS side. The web app's
backend test pins ECDSA P-256 verify against the official CAVP
`186-4` archive (15 vectors), and the iOS app uses the same
algorithm via Apple's CryptoKit. Re-running CAVP in XCTest would
mean shipping the fixture twice; the trade-off is documented in
`tech-spec.md` under "Why no backend on iOS".

The iOS ECDSA tests instead focus on the integration properties
that a CAVP fixture cannot prove on its own (tampering, encoding
conversion, wrong-key, key import round-trip).

## Layer 2 — Roundtrip, boundary, and negative

### `HexTests.swift` (9 tests)

- `testEncodeEmpty`, `testEncodeBasic`,
  `testEncodePadsSingleNibble` — encode produces lowercase hex
  with correct nibble padding.
- `testDecodeEmpty`, `testDecodeBasic`, `testDecodeMixedCase` —
  decode accepts mixed-case input.
- `testDecodeRejectsOddLength`, `testDecodeRejectsInvalidChars` —
  typed errors on malformed input (`HexError.oddLength` and
  `.invalidCharacter`).
- `testRoundtripAllBytes` — every byte from `0x00` to `0xff`
  survives encode + decode.

### `DERTests.swift` (10 tests)

- `testEncodeRejectsWrongRawLength` — both 63-byte and 65-byte
  raw inputs throw `.invalidRawLength`.
- `testEncodeStartsWithSequenceTag` — first byte of output is
  `0x30`.
- Roundtrips: `testRoundtripBasic`, `testRoundtripWithHighBitSet`
  (the ASN.1 INTEGER leading-zero edge case),
  `testRoundtripWithLeadingZeros`.
- Strict acceptance: `testDecodeRejectsTrailingBytes`,
  `testDecodeRejectsLongFormLength`,
  `testDecodeRejectsNonMinimalInteger`,
  `testDecodeRejectsNegativeInteger`,
  `testDecodeRejectsWrongOuterTag`.

### `ECDSATests.swift` (6 tests)

- `testSignVerifyRoundtrip` — sign + verify on a known message.
- `testRawSignatureIs64Bytes` — `rawRepresentation` length.
- `testTamperedMessageRejected` — bit-flip on the message kills
  verification.
- `testWrongKeyRejected` — verify with another keypair returns
  false.
- `testPublicKeyX963IsSEC1Uncompressed` — `x963Representation` is
  65 bytes prefixed with `0x04`.
- `testRawSignatureRoundtripsThroughDER` — `raw -> DER -> raw` is
  the identity, and the resulting raw signature still verifies via
  CryptoKit.

### `PEMTests.swift` (8 tests)

- `testPrivateKeyPemRoundTripPreservesRawRepresentation` and
  `testPublicKeyPemRoundTripPreservesX963Representation` — bytes
  survive export + import for both key types.
- `testImportedPrivateKeyDerivesMatchingPublicKey` — the public
  key derived from the imported private key matches the original.
- `testSignWithImportedKeyVerifiesWithOriginalPublicKey` and
  `testSignWithOriginalKeyVerifiesWithImportedPublicKey` — cross
  verify in both directions proves the imported and the original
  represent the same mathematical keypair.
- `testImportPrivateKeyRejectsPublicKeyPem` and
  `testImportPublicKeyRejectsPrivateKeyPem` — CryptoKit's strict
  parsing rejects wrong-label PEMs.
- `testImportPrivateKeyRejectsMalformedPem` — non-PEM string is
  rejected.

## Layer 3 — Not applicable on iOS

The web app has a cross-implementation matrix in
`tests/integration/cross_verify.test.mjs` that proves byte-exact
agreement between Web Crypto (browser) and `cryptography`
(FastAPI). The iOS app has no second implementation in process,
and the rationale for not adding one is in `tech-spec.md` under
"Why no backend on iOS".

The transitive substitute is fixture-level parity:

- Both stacks pin the same FIPS 180-4 SHA-256 vectors, including
  the NFC vs NFD byte-exact case.
- Both stacks use NIST-conformant ECDSA P-256 implementations
  (`cryptography` runs CAVP on the web side; CryptoKit is the
  same FIPS-validated implementation Apple ships on the iOS
  side).
- Both stacks share the strict DER acceptance set documented in
  `tech-spec.md`.

A drift would surface either as a SHA-256 test failure on one
side, or as a DER encoding test failure on one side, before any
cross-platform demo could be set up to fail.

## How to run everything

From `app/`:
1. Generate the Xcode project
xcodegen generate
2. Run the full test suite
xcodebuild test 

-scheme ThalesAssessment 

-destination 'platform=iOS Simulator,name=iPhone 17'

Expected: `Executed 38 tests, with 0 failures` over five suites
(Hex, DER, SHA-256, ECDSA, PEM). Tested locally on iOS Simulator
26.5.

In CI: `.github/workflows/ci.yml` runs the same suite on
`macos-15` against the first available iPhone simulator on the
runner image (resolved dynamically because Apple rotates default
simulators between Xcode releases). The workflow runs on every
push to `main` and every pull request targeting `main`.

## Future work

- NIST CAVP P-256 vectors. The same fixture is already pinned and
  parsed by the web side; reusing it on iOS is ~1 hour of work
  and would replace the "transitive substitute" with direct
  verification.
- Snapshot tests on `HashIdenticon` to guard against accidental
  visual regressions.
- A `SwiftLint` step in CI. The build already fails on any
  warning, which covers the bulk of what SwiftLint catches, but a
  lint step would pick up style issues that do not produce
  warnings.