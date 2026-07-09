// CancellationTests.swift — Kokoro through the engine's CAN gate (offline, no MLX kernels).
// CAN-1/2 drive the real run() pre-cancelled (the entry checkpoint fires before notLoaded
// validation or weights); CAN-3 is the document of record for the checkpoint cadence.
//
// Kokoro is NON-autoregressive (StyleTTS2 + iSTFTNet): a run is ONE ≤512-token forward chunk —
// there is no inner denoise/token loop to checkpoint. The real seams: the wrapper's entry
// checkpoint (KokoroTTSPackage.run, first act), the core's pre-/post-forward checkpoints
// (KokoroModel.generate — throwing API, CancellationError rethrown unchanged), and the wrapper's
// post-synthesis checkpoint before the CPU sample pull + WAV encode. The cadence is therefore
// honestly COARSE — once per synthesis chunk, and each run() is a single chunk.

import Foundation
import MLXServeConformance
import MLXToolKit
import XCTest
@testable import MLXKokoroTTS

final class CancellationTests: XCTestCase {

    // MARK: - CAN-1 / CAN-2 — pre-cancelled run() propagation + classification

    func testCANGatePreCancelledRun() async {
        // Stub config; construction is cheap (C13) and the entry checkpoint throws before
        // validation or weights are touched, so this is offline-safe.
        let package = KokoroTTSPackage(configuration: KokoroConfiguration())
        let report = await CancellationConformance.checkRun(
            package: package,
            request: TTSRequest(text: "probe"))
        XCTAssertTrue(report.passed, report.summary)
    }

    // MARK: - CAN-3 — checkpoint-cadence declaration (the document of record)

    func testCANCadenceDeclaration() {
        // tts is a long-run capability — the sub-second exemption is not available.
        XCTAssertTrue(CancellationConformance.longRunImplied(by: KokoroTTSPackage.manifest))

        let report = CancellationConformance.checkCadence(
            manifest: KokoroTTSPackage.manifest,
            posture: .cadence([
                // One checkpoint per synthesis chunk — and a run IS one chunk (input hard-capped
                // at maxTokenCount, non-autoregressive single forward). Seams: wrapper entry
                // (KokoroTTSPackage.run), core pre-/post-forward (KokoroModel.generate:161/163),
                // wrapper post-synthesis before WAV encode. Coarse by construction: Kokoro
                // synthesizes ≈ real-time per chunk and has no inner loop to bail from.
                .init(phase: .generate, unit: .chunk),
            ]))
        XCTAssertTrue(report.passed, report.summary)
    }
}
