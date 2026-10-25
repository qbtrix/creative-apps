// DesignLiveCommand.swift (editor-menus EM-4): how the window takes a live
// command's result. LiveCommandChannel runs a catalog command on a copy of the
// front window's workspace (`DesignHeadless`) and hands the copy back; the
// window becomes it unless the copy is another file than the one the window
// shows now. Linux-safe.
extension DesignWorkspace {
    /// Becomes `result`, a copy of this workspace a live command ran on; ignored
    /// when `result` is another document (another `documentURL`).
    public mutating func adoptLiveCommand(_ result: DesignWorkspace) {
        guard result.documentURL == documentURL else { return }
        self = result
    }
}
