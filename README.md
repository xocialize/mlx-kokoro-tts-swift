# mlx-kokoro-tts-swift

An [MLXEngine](https://github.com/xocialize/mlx-engine-swift) model package exposing the **`tts`**
capability over [Kokoro-82M](https://huggingface.co/mlx-community/Kokoro-82M-bf16) on Apple silicon
via [kokoro-mlx-swift](https://github.com/xocialize/kokoro-mlx-swift).

It conforms to the `ModelPackage` contract in `MLXToolKit`: a `PackageManifest`, lazy `load()`, and
a `run()` that maps the canonical `TTSRequest` to Kokoro and returns a canonical `Audio` (16-bit PCM
WAV). The `MLXServeEngine` coordinator handles licensing, device eligibility, and memory budgeting.

## Voices

`KokoroVoice` catalogs the available voices (default: `af_heart`); select one via
`KokoroConfiguration` or per-request through the `VoiceSelector`.

## Usage

```swift
import MLXServeCore
import MLXKokoroTTS

let engine = MLXServeEngine()
try await engine.register(KokoroTTSPackage.registration, configuration: KokoroConfiguration())
try await engine.prepare(.tts)
let response = try await engine.run(TTSRequest(text: "Hello from MLXEngine"))
```

## Development

This package is co-developed inside the MLXEngine workspace and consumes the engine as a tagged-URL
net dependency (`.package(url: "https://github.com/xocialize/mlx-engine-swift", from: "0.3.0")`), so
it builds standalone without a local checkout. The `MLXKokoroTTS` target builds in Swift language
mode v5 to satisfy kokoro-mlx-swift's interop (see the source for details).

## License

MIT — the Swift port. Kokoro-82M weights are licensed by their publisher (Apache-2.0); review the
model card before redistribution.
