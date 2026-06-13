// swift-tools-version: 6.2
import PackageDescription

// mlx-kokoro-tts-swift — the second MLXEngine package: a `tts` surface over Kokoro-82M
// (StyleTTS2 + iSTFTNet, non-autoregressive ≈ real-time), backed by Blaizzy/mlx-audio-swift (MIT).
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
        .package(url: "https://github.com/xocialize/mlx-engine-swift", from: "0.3.0"),
        // Kokoro runtime + G2P (pinned to the companion's known-good revision).
        .package(url: "https://github.com/Blaizzy/mlx-audio-swift.git",
                 revision: "417df212f54b8b4214a9815c1cd2eabb05fd4fdf"),
        // HubCache, to redirect the model download into the engine's chosen models folder
        // (same range mlx-audio resolves, so no version split).
        .package(url: "https://github.com/huggingface/swift-huggingface.git",
                 .upToNextMajor(from: "0.8.1")),
    ],
    targets: [
        .target(
            name: "MLXKokoroTTS",
            dependencies: [
                .product(name: "MLXToolKit", package: "mlx-engine-swift"),
                .product(name: "MLXAudioTTS", package: "mlx-audio-swift"),
                .product(name: "MLXAudioCore", package: "mlx-audio-swift"),
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
            ]
        ),
    ]
)
