# iOS — Thales Assessment (Assignment 2)

Native iOS client for the same FastAPI backend that serves the web app
in `../app/backend/`. Same parity-testing intent: signatures and hashes
produced by Apple's CryptoKit are verified against the backend's
`cryptography` (OpenSSL) implementation over real HTTP.

## Requirements

- macOS with Xcode 15 or later
- xcodegen (`brew install xcodegen`)
- The backend container running (see project root README)

## First-time setup

From the repo root:

    cd ios
    xcodegen generate
    open ThalesAssessment.xcodeproj

In another terminal, start the backend:

    cd ..
    docker compose up -d backend
    curl http://localhost:8000/api/health

## Build and run

In Xcode: select an iPhone simulator, press ⌘R.

`Info.plist` whitelists `NSAllowsLocalNetworking` so the simulator can
reach `http://localhost:8000` without TLS. Physical devices would need a
LAN IP and either a tunnel or LAN-allowed ATS exception; not in scope
for this PoC.

## Tests

In Xcode: ⌘U.

Or from the command line:

    xcodebuild test \
      -project ThalesAssessment.xcodeproj \
      -scheme ThalesAssessment \
      -destination 'platform=iOS Simulator,name=iPhone 15'

## Layout

    ThalesAssessment/
    ├── ThalesAssessmentApp.swift   # entry point
    ├── ContentView.swift           # three stacked cards
    ├── Info.plist                  # ATS exception for localhost
    ├── Views/
    │   ├── Card.swift              # shared titled-card wrapper
    │   ├── HashView.swift
    │   ├── KeysView.swift
    │   └── SignVerifyView.swift
    ├── Crypto/
    │   ├── Hex.swift               # encode/decode, strict
    │   └── DER.swift               # raw ⇄ DER, strict, mirrors der.ts
    └── API/
        ├── APIClient.swift         # URLSession + 5s timeout
        └── DTOs.swift              # Codable types for the 3 endpoints

    ThalesAssessmentTests/
    ├── HexTests.swift              # encode/decode + error cases
    ├── DERTests.swift              # encode/decode + strict acceptance set
    ├── HashTests.swift             # FIPS 180-4 KATs via CryptoKit
    └── ECDSATests.swift            # sign/verify + tamper + DER roundtrip

## Backend reuse

Zero changes. The iOS client speaks the same `/api/hash`,
`/api/verify`, and `/api/sign-test-vector` endpoints as the web client,
with hex on the wire so byte-exact testing (NFC vs NFD `é`) works
identically across both clients.

## Threat model

Inherits the same model as the web app (see
`../specs/tech-spec.md#threat-model`). Notable differences specific to
iOS:

- The private key lives in app-process memory only; it is not stored
  in the Keychain. A real client would Keychain-store with appropriate
  access controls.
- ATS is relaxed only for local networking. Production deployments
  would target HTTPS and remove the relaxation entirely.
- CryptoKit handles constant-time operations on key material; we do
  not reach below the framework.

## Architecture

The iOS app is **self-contained**: CryptoKit handles all crypto locally and
the app has zero network code. No backend or internet connection is required
at any point.

This is intentional. The mobile assignment's "No network dependency required"
constraint is satisfied literally. Cross-stack agreement with the FastAPI
backend (web Assignment 1) is proven at *test time* via shared NIST CAVP and
FIPS 180-4 known-answer vectors in `ThalesAssessmentTests/`, not at *demo
time* via a network round-trip.
