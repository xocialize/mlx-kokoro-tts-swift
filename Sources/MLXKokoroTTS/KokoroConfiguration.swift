import Foundation
import MLXToolKit

/// Init-time configuration for `KokoroTTSPackage` (C9): which Kokoro repo and the default voice
/// (used when a request asks for `.auto`). Per-request voice rides the `TTSRequest`, not here.
public struct KokoroConfiguration: PackageConfiguration, ModelStorable {
    public var repo: String
    public var defaultVoice: String
    /// Explicit snapshot directory (dev escape hatch — never touches the network).
    public var modelDirectory: URL?
    /// Engine-chosen models root (auto-materialization target). Set by the engine from its
    /// `ModelStore`. Excluded from `Codable` (a URL is environment-specific, not portable config).
    public var modelsRootDirectory: URL?

    public init(repo: String = "mlx-community/Kokoro-82M-bf16",
                defaultVoice: String = KokoroVoice.default.id,
                modelDirectory: URL? = nil,
                modelsRootDirectory: URL? = nil) {
        self.repo = repo
        self.defaultVoice = defaultVoice
        self.modelDirectory = modelDirectory
        self.modelsRootDirectory = modelsRootDirectory
    }

    private enum CodingKeys: String, CodingKey {
        case repo, defaultVoice
    }
}

// MARK: - Weight sources (auto-materialization, engine MAT gate)

extension KokoroConfiguration: WeightSourcing {
    /// The Kokoro checkpoint filename in the published repo.
    static let weightsFile = "kokoro-v1_0.safetensors"
    /// Presence probe: config + checkpoint + the configured default voice embedding (the voice
    /// assets ride the same snapshot under `voices/`).
    var requiredFiles: [String] {
        ["config.json", Self.weightsFile, "voices/\(defaultVoice).safetensors"]
    }

    public var weightSources: [WeightSource] {
        // config + checkpoint + all voice embeddings (the repo's samples/ wavs are skipped).
        [WeightSource(role: "main", repo: repo,
                      matching: ["config.json", "*.safetensors", "voices/*.safetensors"])]
    }

    public func missingWeightSources(storeRoot: URL?) -> [WeightSource] {
        let fm = FileManager.default
        func has(_ dir: URL) -> Bool {
            requiredFiles.allSatisfy { fm.fileExists(atPath: dir.appending(path: $0).path) }
        }
        // Explicit local directory first (dev escape hatch), then the ModelStore layout.
        if let dir = modelDirectory, has(dir) { return [] }
        if let dir = ModelStore(root: storeRoot).directory(for: repo), has(dir) { return [] }
        return weightSources
    }

    /// The configuration with a nil `modelDirectory` resolved to the store layout — what `load()`
    /// uses AFTER materialization. An explicit directory always wins.
    public func resolved(storeRoot: URL?) -> KokoroConfiguration {
        var cfg = self
        if cfg.modelDirectory == nil {
            cfg.modelDirectory = ModelStore(root: storeRoot).directory(for: repo)
        }
        return cfg
    }
}

// MARK: - Cold-start prewarm

extension KokoroConfiguration: WeightPrewarming {
    public var prewarmPaths: [URL] {
        // Store-resolved snapshot directory; the prewarmer scans it recursively (checkpoint +
        // voices) and skips it when absent (first launch).
        [resolved(storeRoot: modelsRootDirectory).modelDirectory].compactMap { $0 }
    }
}
