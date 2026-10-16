// PhotoSaveStatusHelp.swift: the tooltip and accessibility hint of the top
// bar's save status. Each status says where the work stands and, when it
// isn't safely in the file, what to do next: an autosave is only a recovery
// copy, and a failed save points to Save As.

extension PhotoSaveStatus {
    /// What this status means for the file named `fileName` ("this image"
    /// when nil or empty).
    public func help(fileName: String?) -> String {
        let file = fileName.flatMap { $0.isEmpty ? nil : $0 } ?? "this image"
        switch self {
        case .saved: return "All changes are saved in \(file)."
        case .edited: return "Changes since \(file) was last saved."
        case .editedAutosaved:
            return "A recovery copy keeps these changes in case Photo quits. Save to write them to \(file)."
        case .notSaved: return "The last save didn't finish. Try File > Save As… to choose another folder."
        }
    }
}
