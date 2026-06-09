# mlx-kokoro-tts-swift

An [MLXEngine](https://github.com/xocialize/mlx-engine-swift) model package exposing the **`tts`**
capability over [Kokoro-82M](https://huggingface.co/mlx-community/Kokoro-82M-bf16) on Apple silicon
via [mlx-audio-swift](https://github.com/Blaizzy/mlx-audio-swift).

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

This package is co-developed inside the MLXEngine workspace and currently depends on the engine via
a local path (`../mlx-engine-swift`). For standalone consumption, switch that to a tagged release of
`mlx-engine-swift`. The `MLXKokoroTTS` target builds in Swift language mode v5 to satisfy
mlx-audio-swift's interop (see the source for details).

## License

MIT — the Swift port. Kokoro-82M weights are licensed by their publisher (Apache-2.0); review the
model card before redistribution.
