// MaterializationTests.swift — Kokoro through the engine's MAT gate (offline, no network):
// the WeightSourcing declaration, fresh-machine honesty, explicit-path satisfaction, and the
// store-layout probe/resolution. Single bf16 snapshot (checkpoint + voices/) — one declaration
// covers the package.

import Foundation
import MLXServeConformance
import MLXToolKit
import XCTest
@testable import MLXKokoroTTS

final class MaterializationTests: XCTestCase {

    /// Temp dir holding probe files that make an explicit-dir config read as satisfied.
    private func satisfiedDir(voice: String) throws -> (dir: URL, cleanup: () -> Void) {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "kokoro-mat-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir.appending(path: "voices"), withIntermediateDirectories: true)
        for f in ["config.json", KokoroConfiguration.weightsFile, "voices/\(voice).safetensors"] {
            FileManager.default.createFile(atPath: dir.appending(path: f).path, contents: Data([0]))
        }
        return (dir, { try? FileManager.default.removeItem(at: dir) })
    }

    // MARK: - Engine MAT gate

    func testMATGate() throws {
        let voice = KokoroVoice.default.id
        let (dir, cleanup) = try satisfiedDir(voice: voice)
        defer { cleanup() }
        let report = MaterializationConformance.check(
            freshConfiguration: KokoroConfiguration(),
            satisfiedConfiguration: KokoroConfiguration(modelDirectory: dir))
        XCTAssertTrue(report.passed, report.summary)
    }

    // MARK: - Source declaration shape

    func testDeclaresSingleMainSourceIncludingVoices() {
        let sources = KokoroConfiguration().weightSources
        XCTAssertEqual(sources.map(\.role), ["main"])
        XCTAssertEqual(sources[0].repo, "mlx-community/Kokoro-82M-bf16")
        XCTAssertEqual(sources[0].matching,
                       ["config.json", "*.safetensors", "voices/*.safetensors"])
    }

    // MARK: - Store-layout probe + resolution

    func testStoreLayoutSatisfiesAndResolves() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "kokoro-store-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let cfg = KokoroConfiguration()
        // Empty store: the source is missing.
        XCTAssertEqual(cfg.missingWeightSources(storeRoot: root).count, 1)
        // Populate the expected layout (checkpoint + the default voice embedding).
        let dir = root.appending(path: cfg.repo)
        try FileManager.default.createDirectory(
            at: dir.appending(path: "voices"), withIntermediateDirectories: true)
        for f in cfg.requiredFiles {
            FileManager.default.createFile(atPath: dir.appending(path: f).path, contents: Data([0]))
        }
        XCTAssertTrue(cfg.missingWeightSources(storeRoot: root).isEmpty)
        // A config for a voice that ISN'T on disk reads as missing (voice assets are sources too).
        let otherVoice = KokoroConfiguration(defaultVoice: "zz_missing")
        XCTAssertEqual(otherVoice.missingWeightSources(storeRoot: root).count, 1)
        // Resolution lands on the store layout; an explicit dir always wins.
        XCTAssertEqual(cfg.resolved(storeRoot: root).modelDirectory?.path, dir.path)
        let explicit = KokoroConfiguration(modelDirectory: URL(fileURLWithPath: "/x"))
            .resolved(storeRoot: root)
        XCTAssertEqual(explicit.modelDirectory?.path, "/x")
    }

    func testPrewarmPathsUseResolvedStoreLayout() {
        let root = URL(fileURLWithPath: "/tmp/some-store")
        let cfg = KokoroConfiguration(modelsRootDirectory: root)
        XCTAssertEqual(cfg.prewarmPaths.map(\.path),
                       [root.appending(path: "mlx-community/Kokoro-82M-bf16").path])
    }

    func testCodableRoundTrip() throws {
        let cfg = KokoroConfiguration(defaultVoice: "af_bella",
                                      modelDirectory: URL(fileURLWithPath: "/x"))
        let decoded = try JSONDecoder().decode(KokoroConfiguration.self,
                                               from: JSONEncoder().encode(cfg))
        XCTAssertEqual(decoded.repo, cfg.repo)
        XCTAssertEqual(decoded.defaultVoice, "af_bella")
        XCTAssertNil(decoded.modelDirectory)   // environment-specific, never encoded
    }
}
