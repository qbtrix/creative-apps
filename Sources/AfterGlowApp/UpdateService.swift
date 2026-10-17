// UpdateService.swift: the launcher's updater member. LauncherServices hands
// `checker()` to `SuiteServices.with(updates:)`; nil keeps the live services'
// fake until the updater feature (UP-2) returns the real UpdateChecking here.
import SuiteModel

enum UpdateService {
    /// The live updater; nil while the updater feature hasn't built it.
    static func checker() -> (any UpdateChecking)? { nil }
}
