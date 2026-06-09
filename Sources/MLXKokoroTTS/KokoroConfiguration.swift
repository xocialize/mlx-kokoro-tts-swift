import Foundation
import MLXToolKit

/// Init-time configuration for `KokoroTTSPackage` (C9): which Kokoro repo and the default voice
/// (used when a request asks for `.auto`). Per-request voice rides the `TTSRequest`, not here.
public struct KokoroConfiguration: PackageConfiguration, ModelStorable {
    public var repo: String
    public var defaultVoice: String
    /// Where weights are materialized. Set by the engine from its `ModelStore`; `nil` → mlx-audio's
    /// default cache. Excluded from `Codable` (a URL is environment-specific, not portable config).
    public var modelsRootDirectory: URL?

    public init(repo: String = "mlx-community/Kokoro-82M-bf16",
                defaultVoice: String = KokoroVoice.default.id,
                modelsRootDirectory: URL? = nil) {
        self.repo = repo
        self.defaultVoice = defaultVoice
        self.modelsRootDirectory = modelsRootDirectory
    }

    private enum CodingKeys: String, CodingKey {
        case repo, defaultVoice
    }
}
