// CommandIDLedger.swift (command-catalog CC-1 stub, CC-8 body): catalog ids against the app's ledger.

/// Checks a catalog's ids against `Tests/command-ids/<app>.txt`: one id per line, "retired <id>" for a removed one.
/// Blank lines and lines starting with "#" are skipped; a line that says both an id and "retired <id>" reads as retired.
public enum CommandIDLedger {
    /// The problems: an id removed without retiring it, a retired id back. Empty when the ids keep the ledger.
    /// Each problem names the id and the law it broke (`CatalogLaw.removedIsRetired`, `.retiredNeverReused`).
    public static func check(_ ids: [String], ledger: String) -> [String] {
        var live = Set<String>(), retired = Set<String>()
        for raw in ledger.split(whereSeparator: \.isNewline) {
            let line = trimmed(raw)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("retired ") {
                retired.insert(trimmed(line.dropFirst("retired ".count)))
            } else {
                live.insert(line)
            }
        }
        let current = Set(ids)
        let removed = live.subtracting(retired).subtracting(current).sorted().map {
            CatalogLaw.removedIsRetired.problem($0, "the ledger lists it, the catalog dropped it; add \"retired \($0)\" to the ledger")
        }
        let back = current.intersection(retired).sorted().map {
            CatalogLaw.retiredNeverReused.problem($0, "the ledger retired it, the catalog uses it again; pick a new id")
        }
        return removed + back
    }
    /// `text` without its leading and trailing whitespace.
    static func trimmed(_ text: Substring) -> String {
        String(text.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
    }
}
