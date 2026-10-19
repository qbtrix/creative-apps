// CommandIDLedger.swift (command-catalog CC-1 stub, CC-8 body): catalog ids against the app's ledger.

/// Checks a catalog's ids against `Tests/command-ids/<app>.txt`: one id per line, "retired <id>" for a removed one.
public enum CommandIDLedger {
    /// The problems: an id removed without retiring it, a retired id back. Empty when the ids keep the ledger.
    /// CC-1 stub: reports itself as not built until command-catalog CC-8.
    public static func check(_ ids: [String], ledger: String) -> [String] {
        ["CommandIDLedger.check is not built yet (command-catalog CC-8)"]
    }
}
