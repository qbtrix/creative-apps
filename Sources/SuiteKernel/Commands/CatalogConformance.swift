// CatalogConformance.swift (command-catalog CC-1 stub, CC-8 body): the laws every app's catalog keeps.

/// The conformance suite any `HeadlessDocument`'s catalog runs.
public enum CatalogConformance {
    /// Every spec of D's catalog on `fixture`: the example validates and runs, an edit records one step named
    /// its title and "edit.undo" restores save() bytes, query and view leave save() bytes equal, a refusal changes
    /// nothing, describe round trips through JSON. Returns the problems, empty when it conforms.
    /// CC-1 stub: reports itself as not built until command-catalog CC-8.
    public static func check<D: HeadlessDocument>(_ type: D.Type, fixture: D) -> [String] {
        ["CatalogConformance.check is not built yet (command-catalog CC-8)"]
    }
}
