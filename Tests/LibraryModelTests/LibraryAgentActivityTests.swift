// LibraryAgentActivityTests.swift: Library's AI-tab adapter: an agent's steps,
// a photo edit and a collections step recorded outside recordEdit, as one
// loose request with no layers; a user's steps left out.
import SuiteKernel
import Testing

@testable import LibraryModel

@Suite struct LibraryAgentActivityTests {
    @Test func agentStepsBecomeOneLooseRequest() {
        var shoot = LibraryCatalog()
        shoot.load(LibraryFixtures.photos(named: "shoot"))
        shoot.select([shoot.order[0]])
        shoot.setRating(2)
        #expect(shoot.agentRequests.isEmpty, "a user's steps listed as an agent's")
        StepOrigin.$current.withValue(.agent(client: "claude", request: nil)) {
            shoot.setRating(5)
            shoot.newCollection()
        }
        let requests = shoot.agentRequests
        #expect(requests.count == 1, "\(requests)")
        let request = requests.first
        #expect(request?.client == "claude" && request?.isSpan == false && request?.layers.isEmpty == true)
        #expect(request?.steps.count == 2 && (request?.date ?? .distantPast) > .distantPast)
    }
}
