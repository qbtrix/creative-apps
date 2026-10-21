// FakeAIAccessTests.swift (afterglow-mcp #3350): the demo client asks again
// once after its first Stop, so the approval journey sees an allow-once end.
import SuiteModel
import Testing

@Suite struct FakeAIAccessTests {
    @Test func theDemoClientAsksAgainOnceAfterStop() {
        var access = FakeAIAccess(app: "AfterGlow", demoClient: FakeAIAccess.demoClient)
        access.request(client: FakeAIAccess.demoClient)
        access.decide(.allowOnce)
        access.stop()
        #expect(access.connectedClient == nil && access.pending == AIAccessRequest(client: "Test Client", app: "AfterGlow"))
        access.decide(.allowOnce)
        access.stop()
        #expect(access.connectedClient == nil && access.pending == nil && access.grants.entries.isEmpty)
    }

    @Test func withoutADemoClientStopAsksNothing() {
        var access = FakeAIAccess(app: "AfterGlow")
        access.request(client: "c")
        access.decide(.allowOnce)
        access.stop()
        #expect(access.connectedClient == nil && access.pending == nil)
    }
}
