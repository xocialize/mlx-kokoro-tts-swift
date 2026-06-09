import Foundation

/// A Kokoro voice id. Kokoro ships named voices (the `a*` = American, `b*` = British prefixes);
/// the canonical `VoiceSelector.named(_)` carries the id, so this is a convenience catalog.
public enum KokoroVoice: String, Sendable, Codable, CaseIterable {
    case afHeart = "af_heart"
    case afBella = "af_bella"
    case afNicole = "af_nicole"
    case afSarah = "af_sarah"
    case amAdam = "am_adam"
    case amMichael = "am_michael"
    case bfEmma = "bf_emma"
    case bfIsabella = "bf_isabella"
    case bmGeorge = "bm_george"
    case bmLewis = "bm_lewis"

    public var id: String { rawValue }

    /// A sensible default voice.
    public static let `default` = KokoroVoice.afHeart
}
