// DesignExportRequest.swift: File > Export…'s request, the one thing DesignWindow and its export
// area share. A reference the window holds but never reads, so a bump re-runs only
// DesignExportArea (which watches `count`) and never the window's body: that re-run cost the
// sheet's open ~40 ms (RenderBudgetDesignExportTests.sheet counts 0 window bodies).
// Presentation state only.
import Observation

@MainActor @Observable final class DesignExportRequest {
    /// Bumped once per File > Export…; each change opens the sheet.
    private(set) var count = 0

    func bump() { count += 1 }
}
