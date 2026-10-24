// StyleProgramTests.swift (layer-styles LS-1 written disabled, LS-8 turns it on and adds the
// colour, round-trip and padding cases; cpuEqualsGpu lands with the route in LS-9): LayerStyle to core's stack.
import Testing
import SuiteImaging
import SuiteKernel

@Suite(.disabled("waits on LS-8")) struct StyleProgramTests {
    /// 135° and 8 px map to core's (dx, dy) = (5.66, 5.66); scale 2 doubles every px.
    @Test func angleIsDegreesYDown() {
        for (scale, expected) in [(1.0, 5.657), (2.0, 11.314)] {
            guard case .dropShadow(_, let dx, let dy, _, _)? = StyleProgram.stack(shadowStyle(), scale: scale).entries.first?.op
            else { Issue.record("no shadow"); return }
            #expect(abs(dx - expected) < 0.01 && abs(dy - expected) < 0.01)
        }
    }
}
