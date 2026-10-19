// AIAccessGrantsTests.swift (afterglow-mcp MC-9): the grants ask with none,
// allow an always and refuse a deny for that client in that app only, never
// remember allow once, always ask for a file command, revoke per app or
// everywhere, and round-trip through the suite preferences store.
import SuiteModel
import Testing

@Suite struct AIAccessGrantsTests {
    @Test func noGrantAsksAndAllowOnceIsNotRemembered() {
        var grants = AIAccessGrants()
        #expect(grants.allows(client: "c", app: "photo", kind: "edit") == nil)
        grants.record(.allowOnce, client: "c", app: "photo")
        #expect(grants.entries.isEmpty)
        #expect(grants.allows(client: "c", app: "photo", kind: "edit") == nil)
    }

    @Test func alwaysAllowsThatClientInThatAppOnly() {
        var grants = AIAccessGrants()
        grants.record(.alwaysForClient, client: "c", app: "photo")
        #expect(grants.allows(client: "c", app: "photo", kind: "edit") == true)
        #expect(grants.allows(client: "c", app: "photo", kind: "query") == true)
        #expect(grants.allows(client: "c", app: "flare", kind: "edit") == nil)
        #expect(grants.allows(client: "other", app: "photo", kind: "edit") == nil)
    }

    @Test func denyRefusesWithoutAsking() {
        var grants = AIAccessGrants()
        grants.record(.deny, client: "c", app: "photo")
        #expect(grants.allows(client: "c", app: "photo", kind: "edit") == false)
        #expect(grants.entries == [AIAccessEntry(client: "c", app: "photo", decision: .deny)])
    }

    @Test func aFileCommandAlwaysAsks() {
        var grants = AIAccessGrants()
        grants.record(.alwaysForClient, client: "c", app: "photo")
        #expect(grants.allows(client: "c", app: "photo", kind: AIAccessGrants.fileKind) == nil)
        grants.record(.deny, client: "c", app: "photo")
        #expect(grants.allows(client: "c", app: "photo", kind: "file") == nil)
    }

    @Test func aNewDecisionReplacesTheOldOneAndEntriesSortByClientThenApp() {
        var grants = AIAccessGrants()
        grants.record(.alwaysForClient, client: "b", app: "photo")
        grants.record(.alwaysForClient, client: "a", app: "photo")
        grants.record(.alwaysForClient, client: "a", app: "flare")
        grants.record(.deny, client: "b", app: "photo")
        #expect(grants.allows(client: "b", app: "photo", kind: "edit") == false)
        #expect(grants.entries == [AIAccessEntry(client: "a", app: "flare", decision: .alwaysForClient),
                                   AIAccessEntry(client: "a", app: "photo", decision: .alwaysForClient),
                                   AIAccessEntry(client: "b", app: "photo", decision: .deny)])
    }

    @Test func revokeIsScopedToTheAppAndClient() {
        var grants = AIAccessGrants()
        grants.record(.alwaysForClient, client: "c", app: "photo")
        grants.record(.alwaysForClient, client: "c", app: "flare")
        grants.record(.alwaysForClient, client: "d", app: "photo")
        grants.revoke(client: "c", app: "photo")
        #expect(grants.allows(client: "c", app: "photo", kind: "edit") == nil)
        #expect(grants.allows(client: "c", app: "flare", kind: "edit") == true)
        #expect(grants.allows(client: "d", app: "photo", kind: "edit") == true)
        grants.revoke(client: "c", app: nil)
        #expect(grants.entries == [AIAccessEntry(client: "d", app: "photo", decision: .alwaysForClient)])
    }

    @Test func grantsLiveInPerAppKeysBesideTheAppsOwn() {
        var grants = AIAccessGrants()
        grants.record(.alwaysForClient, client: "Test Client", app: "photo")
        grants.record(.deny, client: "x", app: "flare")
        let prefs = SuitePreferences(perApp: ["photo": ["grid": "on", "aiAccess.old": "deny"], "halo": ["aiAccess.gone": "deny"]])
        let stored = grants.stored(in: prefs)
        #expect(stored.perApp == ["photo": ["grid": "on", "aiAccess.Test Client": "alwaysForClient"],
                                  "flare": ["aiAccess.x": "deny"]])
        #expect(AIAccessGrants(preferences: stored) == grants)
        let junk = SuitePreferences(perApp: ["photo": ["aiAccess.c": "maybe", "grid": "deny"]])
        #expect(AIAccessGrants(preferences: junk).entries.isEmpty)
    }

    @Test func grantsRoundTripThroughThePreferencesStore() async throws {
        let store = FakePreferences(SuitePreferences(units: .pixels, perApp: ["photo": ["grid": "on"]]))
        var grants = try await AIAccessGrants.load(from: store)
        #expect(grants.entries.isEmpty)
        grants.record(.alwaysForClient, client: "c", app: "photo")
        try await grants.save(to: store)
        let saved = await store.stored
        #expect(saved.revision == 1 && saved.units == .pixels && saved.perApp["photo"]?["grid"] == "on")
        #expect(try await AIAccessGrants.load(from: store) == grants)
        grants.revoke(client: "c", app: "photo")
        try await grants.save(to: store)
        #expect(try await AIAccessGrants.load(from: store).entries.isEmpty)
        #expect(await store.stored.perApp == ["photo": ["grid": "on"]])
    }
}
