// PhotoSaveStatusHelp.swift: the tooltip and accessibility hint of the top
// bar's save status. Each status says where the work stands and, when it
// isn't safely in the file, what to do next: an autosave is only a recovery
// copy, and a failed save points to Save As.

extension PhotoSaveStatus {
    /// What this status means for the file named `fileName` ("this image"
    /// when nil or empty).
    public func help(fileName: String?) -> String {
        let file = fileName.flatMap { $0.isEmpty ? nil : $0 } ?? "this image"
        // Through the kernel's SaveStatus (PhotoRecovery+Kernel.swift); only
        // an autosave, which the kernel doesn't track, is told apart here.
        switch kernelStatus {
        case .saved: return "All changes are saved in \(file)."
        case .failed(let words): return words
        case .unsaved, .saving, .readOnly:
            guard self == .editedAutosaved else { return "Changes since \(file) was last saved." }
            return "A recovery copy keeps these changes in case Photo quits. Save to write them to \(file)."
        }
    }
}
