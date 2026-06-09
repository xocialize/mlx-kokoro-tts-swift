import Testing
import Foundation
import MLXToolKit
import MLXServeCore
@testable import MLXKokoroTTS

@Test func manifestExposesTTSAndIsPermissive() {
    let manifest = KokoroTTSPackage.manifest
    #expect(manifest.capabilities == [.tts])
    #expect(LicensePolicy.permissiveOnly.evaluate(manifest.license).isAdmitted)
    #expect(manifest.surfaces.count == 1)
}

@Test func registrationConstructsPackage() throws {
    // Construct only — load()/run() download weights + run on the GPU (device/integration test).
    let package = try KokoroTTSPackage.registration.makePackage(KokoroConfiguration())
    #expect(package is KokoroTTSPackage)
}

@Test func voiceCatalogHasDefault() {
    #expect(KokoroVoice.default == .afHeart)
    #expect(KokoroVoice.allCases.contains(.afHeart))
    #expect(KokoroConfiguration().defaultVoice == "af_heart")
}

@Test func wavEncoderWritesValidHeader() {
    let samples: [Float] = [0, 0.5, -0.5, 1.0]
    let data = KokoroTTSPackage.encodeWAV16(samples: samples, sampleRate: 24_000)
    #expect(data.count == 44 + samples.count * 2)
    #expect(data.prefix(4) == Data("RIFF".utf8))
    #expect(data.subdata(in: 8..<12) == Data("WAVE".utf8))
    #expect(data.subdata(in: 36..<40) == Data("data".utf8))
}

@Test func admissibleOnModestBudget() async {
    // Kokoro is small (~0.5 GB) — admissible even on a 1 GB budget; the engine reports it.
    let device = DeviceProfile(chipTier: .base, macOS: SemanticVersion(major: 26, minor: 0, patch: 0),
                               backends: [.metalGPU], totalMemoryBytes: 8_000_000_000)
    let engine = MLXServeEngine(device: device, governor: MemoryGovernor(budgetBytes: 1_000_000_000))
    let verdict = await engine.admissibility(for: KokoroTTSPackage.manifest.requirements)
    #expect(verdict.admissible)
    #expect(verdict.eligibility.isEligible)
}
