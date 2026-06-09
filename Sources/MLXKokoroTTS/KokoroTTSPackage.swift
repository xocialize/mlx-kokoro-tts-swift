import Foundation
import MLXToolKit
import MLX
import MLXAudioTTS
import MLXAudioCore
import HuggingFace

/// The second MLXEngine package: Kokoro-82M exposing the canonical `tts` surface.
///
/// Engine-owned lifecycle (C13): the engine constructs from a `KokoroConfiguration`, pages weights
/// in with `load()` (Blaizzy/mlx-audio-swift downloads + caches on first run), drives `run(_:)`, and
/// reclaims with `unload()`. Returns the canonical `Audio` (.wav) artifact — prose/playback stays
/// with the consumer.
@InferenceActor
public final class KokoroTTSPackage: ModelPackage {
    public typealias Configuration = KokoroConfiguration

    public nonisolated static var manifest: PackageManifest {
        PackageManifest(
            // Kokoro-82M weights are Apache-2.0; the runtime port (mlx-audio-swift) is MIT.
            license: LicenseDeclaration(weightLicense: .apache2, portCodeLicense: .mit),
            provenance: Provenance(sourceRepo: "mlx-community/Kokoro-82M-bf16", revision: "main", tier: 1),
            requirements: RequirementsManifest(
                // 82M params bf16 (~165 MB) + vocoder/G2P + runtime headroom.
                footprints: [QuantFootprint(quant: .bf16, residentBytes: 500_000_000)],
                requiredBackends: [.metalGPU],
                os: OSRequirement(minMacOS: SemanticVersion(major: 26, minor: 0, patch: 0)),
                chipFloor: nil
            ),
            specialties: [],
            surfaces: [
                TTSContract.descriptor(
                    name: "kokoro-tts",
                    summary: "Kokoro-82M fast on-device text-to-speech (.wav).",
                    modes: [.neutral, .expressive]
                )
            ]
        )
    }

    private let configuration: Configuration
    // `SpeechGenerationModel` is a non-Sendable, `@concurrent`-driven resource from the un-audited
    // mlx-audio-swift. The engine serializes all lifecycle calls on InferenceActor, so there's no
    // real concurrency — this target builds in Swift language mode v5 (see Package.swift) so the
    // strict region-isolation "sending" check on `generate` relaxes to a warning.
    private var model: SpeechGenerationModel?

    public nonisolated init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func load() async throws {
        guard model == nil else { return }
        // `TTS.loadModel` auto-detects the architecture, attaches the Misaki G2P, and downloads +
        // caches the weights from HF on first run. When the engine has set a model-store root,
        // redirect the Hub cache there (the caller holds security-scoped access) so weights land in
        // the chosen models folder instead of the default container cache.
        let cache: HubCache = configuration.modelsRootDirectory
            .map { HubCache(cacheDirectory: $0) } ?? .default
        model = try await TTS.loadModel(modelRepo: configuration.repo, cache: cache)
    }

    public func unload() async {
        model = nil
    }

    public func run(_ request: any CapabilityRequest) async throws -> any CapabilityResponse {
        guard let model else { throw PackageError.notLoaded }
        guard request.capability == .tts, let tts = request as? TTSRequest else {
            throw PackageError.unsupportedCapability(request.capability)
        }
        try Task.checkCancellation()

        let voice = resolveVoice(tts.voice)
        let waveform = try await model.generate(
            text: tts.text,
            voice: voice,
            refAudio: nil,
            refText: nil,
            language: nil,
            generationParameters: model.defaultGenerationParameters
        )
        let samples = waveform.asType(.float32).asArray(Float.self) // 1-D mono
        let sampleRate = Int(model.sampleRate)
        let wav = Self.encodeWAV16(samples: samples, sampleRate: sampleRate)
        return TTSResponse(audio: Audio(format: .wav, data: wav, sampleRate: sampleRate, channels: 1))
    }

    /// Kokoro uses **named** voices; reference-audio cloning isn't supported, so `.auto` and
    /// `.referenceAudio` fall back to the configured default voice.
    private func resolveVoice(_ selector: VoiceSelector) -> String {
        switch selector.selection {
        case .named(let id): return id
        case .auto, .referenceAudio: return configuration.defaultVoice
        }
    }

    /// Encodes mono float samples as a 16-bit PCM WAV (broadly playable) in memory.
    nonisolated static func encodeWAV16(samples: [Float], sampleRate: Int) -> Data {
        let channels = 1
        let bitsPerSample = 16
        let blockAlign = channels * bitsPerSample / 8
        let byteRate = sampleRate * blockAlign
        let dataSize = samples.count * blockAlign

        var data = Data(capacity: 44 + dataSize)
        func ascii(_ s: String) { data.append(contentsOf: Array(s.utf8)) }
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }

        ascii("RIFF"); u32(UInt32(36 + dataSize)); ascii("WAVE")
        ascii("fmt "); u32(16); u16(1) // PCM
        u16(UInt16(channels)); u32(UInt32(sampleRate)); u32(UInt32(byteRate))
        u16(UInt16(blockAlign)); u16(UInt16(bitsPerSample))
        ascii("data"); u32(UInt32(dataSize))

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            var le = Int16(clamped * 32767).littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        return data
    }
}

extension KokoroTTSPackage {
    /// The author one-liner the engine registers.
    public nonisolated static var registration: PackageRegistration {
        .of(KokoroTTSPackage.self)
    }
}
