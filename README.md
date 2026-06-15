# Thales assessment — iOS

ECDSA P-256 sign/verify and SHA-256 hashing demo, native iOS, built
with Swift, SwiftUI, and CryptoKit. Self-contained: no backend, no
network calls.

Assignment 2 of 2 of the Thales Singapore AI Innovation Engineer
take-home. Companion web app:
https://github.com/TheNarciss/thales-assessment-web

![CI](https://github.com/TheNarciss/thales-assessment-ios/actions/workflows/ci.yml/badge.svg)

## Run

Requires macOS with Xcode 16+ and `xcodegen`.
brew install xcodegen

cd app

xcodegen generate

open ThalesAssessment.xcodeproj

In Xcode: select an iPhone simulator (any iOS 17+), press ⌘R.

The app has three tabs:

- **Hash**: type, see the SHA-256 digest and a 7×7 identicon update
  live (300 ms debounce).
- **Keys**: generate or import a P-256 keypair, toggle between hex
  and PEM display, reveal the private scalar behind a tap gate.
  Import opens a sheet for pasting a PKCS#8 PEM.
- **Sign**: sign the current message with the loaded keypair, see
  both raw P1363 and DER ASN.1 forms in hex, tamper a byte and
  watch verification flip, reset, repeat.

## Tests
cd app

xcodebuild test 

-scheme ThalesAssessment 

-destination 'platform=iOS Simulator,name=iPhone 17'

Or in Xcode: ⌘U.

Expected: `Executed 38 tests, with 0 failures` across Hex (9), DER
(10), SHA-256 KAT (5), ECDSA (6), PEM (8).

## Repo layout
app/

├── ThalesAssessment/             # app source

│   ├── ThalesAssessmentApp.swift   # entry point

│   ├── ContentView.swift           # TabView with three tabs

│   ├── Info.plist

│   ├── Crypto/

│   │   ├── Hex.swift             # strict hex encode/decode

│   │   └── DER.swift             # strict raw <-> DER converter

│   └── Views/

│       ├── HashView.swift

│       ├── KeysView.swift        # generate, display, import

│       ├── SignVerifyView.swift  # sign, tamper, verify

│       └── HashIdenticon.swift   # 7×7 deterministic visual

├── ThalesAssessmentTests/        # 38 XCTest cases

│   ├── HexTests.swift

│   ├── DERTests.swift

│   ├── HashTests.swift           # FIPS 180-4 KATs via CryptoKit

│   ├── ECDSATests.swift          # roundtrip / tamper / wrong-key

│   └── PEMTests.swift            # PKCS#8 + SPKI round-trip

├── ThalesAssessment.xcodeproj/   # generated from project.yml

└── project.yml                   # xcodegen source of truth
specs/

├── requirements.md               # FR-1 to FR-6, NFR, out of scope

├── tech-spec.md                  # architecture, threat model, AI workflow

└── verification.md               # test layers, what each covers
.github/workflows/ci.yml          # xcodebuild test on macos-15

## Where to look first

If you have 5 minutes: read `specs/tech-spec.md`. It explains why
this app exists in its current shape — why no backend, why a
strict DER converter, why the identicon, what was scoped out (an
HTTP client to the web's FastAPI was prototyped and rejected).

If you have 15 minutes: open the project in Xcode, generate a
keypair, sign a message, tap Tamper, then read
`specs/verification.md` to see the test matrix.

## No network

Unlike the companion web app, this iOS app has no network layer:
no `URLSession`, no analytics, no telemetry. CryptoKit handles all
crypto locally. The mobile assignment's "No network dependency
required" constraint is satisfied literally.

Cross-stack agreement with the web app's FastAPI backend is proven
at test time via shared NIST CAVP and FIPS 180-4 known-answer
vectors, not at demo time via a network round-trip. See
`specs/tech-spec.md` section "Why no backend on iOS" for the full
argument.