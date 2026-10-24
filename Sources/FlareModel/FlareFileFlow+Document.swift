// FlareFileFlow+Document.swift: the open animation as the suite names it (file-flow FL-2), which File >
// Open In ▸ (SuiteFileCommands) hands to another app. The window's open and save note the file's path at the
// head of `recent` and set `fileName` to its name, so the open document is that head while the names agree
// (the rule Save uses for where to write). Nil with no document or before it has a file on disk.
// Linux-safe.
import SuiteModel

extension FlareWorkspace {
    /// The open animation's file as a suite ref; nil with none open or before it is opened from or saved to a file.
    public var suiteDocument: SuiteDocumentRef? {
        guard document != nil, let name = fileName, let path = recent.first,
              path.split(separator: "/").last.map(String.init) == name else { return nil }
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .flare,
                                type: .flareAnimation, displayName: name)
    }
}
