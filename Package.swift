// swift-tools-version: 6.2
import PackageDescription

// mlx-kokoro-tts-swift — the second MLXEngine package: a `tts` surface over Kokoro-82M
// (StyleTTS2 + iSTFTNet, non-autoregressive ≈ real-time), backed by our kokoro-mlx-swift core
// (MIT, vendored from the validated Blaizzy/mlx-audio-swift @ 417df212).
// Conforms to the MLXEngine contract (MLXToolKit) and returns the canonical `Audio` (.wav) artifact
// — rebuilt fresh from the companion app's `KokoroVoiceBox` (which used a temp-file `SpeechResult`).
//
// Swift-port naming: `-swift` on the package/repo; module/product stays clean `MLXKokoroTTS`.
let package = Package(
    name: "mlx-kokoro-tts-swift",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "MLXKokoroTTS", targets: ["MLXKokoroTTS"]),
    ],
    dependencies: [
        // Bumped to 0.23.0 for the WeightSourcing auto-materialization contract (types ≥0.19.0).
        .package(url: "https://github.com/xocialize/mlx-engine-swift", from: "0.23.0"),
        // Kokoro-82M runtime + misaki English G2P — our own vendored core, consumed by version
        // (no `revision:` pin, so this wrapper is version-consumable like every other in the roster).
        .package(url: "https://github.com/xocialize/kokoro-mlx-swift.git", from: "0.1.0"),
        // HubClient — the native downloader for WeightSourcing auto-materialization.
        .package(url: "https://github.com/huggingface/swift-huggingface.git",
                 .upToNextMajor(from: "0.9.0")),
    ],
    targets: [
        .target(
            name: "MLXKokoroTTS",
            dependencies: [
                .product(name: "MLXToolKit", package: "mlx-engine-swift"),
                .product(name: "KokoroMLX", package: "kokoro-mlx-swift"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
            ],
            // mlx-audio-swift isn't Sendable-audited and its `generate` is `@concurrent`; the engine
            // serializes lifecycle on InferenceActor (no real concurrency), so v5 mode keeps the
            // strict region-isolation send a warning rather than a hard error. The `@InferenceActor`
            // isolation still holds.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MLXKokoroTTSTests",
            dependencies: [
                "MLXKokoroTTS",
                // Test-only: admissibility sanity check through the engine.
                .product(name: "MLXServeCore", package: "mlx-engine-swift"),
                // The offline MAT-1..5 materialization gate.
                .product(name: "MLXServeConformance", package: "mlx-engine-swift"),
            ]
        ),
    ]
)
