import Foundation
import MLXToolKit

/// Init-time configuration for `KokoroTTSPackage` (C9): which Kokoro repo and the default voice
/// (used when a request asks for `.auto`). Per-request voice rides the `TTSRequest`, not here.
public struct KokoroConfiguration: PackageConfiguration {
    public var repo: String
    public var defaultVoice: String

    public init(repo: String = "mlx-community/Kokoro-82M-bf16",
                defaultVoice: String = KokoroVoice.default.id) {
        self.repo = repo
        self.defaultVoice = defaultVoice
    }
}
