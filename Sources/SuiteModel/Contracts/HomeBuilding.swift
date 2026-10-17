// HomeBuilding.swift: UC-16, build the home's state (tier 1). Foundation
// only for `Date`, Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// UC-16 Build the home's state (tier 1). Pure.
public protocol HomeBuilding: Sendable {
    func home(recents: RecentsList, running: [SuiteApp], query: String, filter: SuiteApp?,
              order: [SuiteApp], missingApps: Set<SuiteApp>, missingFiles: Set<String>, now: Date) -> HomeState
}
