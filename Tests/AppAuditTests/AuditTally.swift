// AuditTally.swift: the app audit's ratchet (docs/blueprints/app-audit.md).
// One app's distinct violations per check across its audited screens, held
// against the app's line in UITests/audit-baseline.json in both directions:
// a count that rises fails at the screen that raised it, a count that fell
// fails when the app's journeys end, until the baseline comes down with it.
// Placement and naming: see AuditPixels.swift.
extension AppAudit {
    /// The distinct violations of one app's audited screens, per check, held
    /// against the app's line in the baseline (nil: the app isn't listed, so
    /// nothing is judged). A violation is its element: type and name, so a
    /// slider seen on ten screens, wherever the panel puts it, counts once;
    /// an element with no name is told apart by its frame.
    struct Tally: Sendable {
        let app: String
        let baseline: [String: Int]?
        private(set) var seen: [String: Set<String>] = [:]

        init(app: String, baseline: [String: Int]?) {
            self.app = app
            self.baseline = baseline
        }

        /// Adds a screen; one message per new violation that takes its
        /// check past the baseline.
        mutating func add(_ report: Report, checks: [any Check] = AppAudit.checks) -> [String] {
            var failures = [String]()
            for v in report.violations {
                let f = v.frame
                let place = "\(v.element) at [\(Int(f.x)),\(Int(f.y)),\(Int(f.width)),\(Int(f.height))]"
                let key = v.element.hasSuffix("''") ? place : v.element
                guard seen[v.check, default: []].insert(key).inserted, let baseline else { continue }
                let count = seen[v.check, default: []].count, allowed = baseline[v.check, default: 0]
                if count > allowed {
                    failures.append(
                        "\(app) \(v.check) (\(fault(v.check, checks))): \(count) violations, baseline \(allowed). "
                            + "New on \(report.screen): \(place), \(v.detail).")
                }
            }
            return failures
        }

        /// After the app's last journey: one message per check now under its
        /// baseline, which must come down to match.
        func lower(checks: [any Check] = AppAudit.checks) -> [String] {
            guard let baseline else { return [] }
            return baseline.keys.sorted().compactMap { id in
                let count = seen[id, default: []].count, allowed = baseline[id, default: 0]
                guard count < allowed else { return nil }
                return "\(app) \(id) (\(fault(id, checks))): \(count) violations, under the baseline \(allowed). "
                    + "Lower it to \(count) in UITests/audit-baseline.json."
            }
        }

        private func fault(_ id: String, _ checks: [any Check]) -> String {
            checks.first { $0.id == id }.map { "fault \($0.fault)" } ?? "no such check"
        }
    }
}
