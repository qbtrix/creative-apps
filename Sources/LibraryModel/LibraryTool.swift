// LibraryTool.swift: the loupe's canvas tools (#6022). Library has no tool
// palette: the loupe's mode picks the tool. Outside crop a canvas drag only
// gives the canvas its keys (`view`); while a crop draft is open it moves the
// crop handle under the press, or the whole frame (`crop`). LibraryApp
// conforms it to SuiteUI's PaletteTool, so the gesture contract
// (Tests/AppSnapshotTests/GestureContractTests.swift) holds each tool to its
// class's budget. Linux-safe.

/// A canvas tool of the loupe.
public enum LibraryTool: String, CaseIterable, Sendable {
    case view, crop
}

extension LibraryCatalog {
    /// The tool a canvas drag uses: `crop` while a draft is open, else `view`.
    public var loupeTool: LibraryTool { cropDraft == nil ? .view : .crop }
}
