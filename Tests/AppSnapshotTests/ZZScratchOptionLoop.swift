#if canImport(AppKit)
import Testing
@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct ZZScratchOptionLoop {
        @Test(.timeLimit(.minutes(5))) func loop() async throws {
            for _ in 0..<6 { _ = try await RenderBudgetDesignTests.optionDrag() }
        }
    }
}
#endif
