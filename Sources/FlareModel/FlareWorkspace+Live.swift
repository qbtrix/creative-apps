// FlareWorkspace+Live.swift (editor-menus EM-5): how a window takes a live command's result. The suite's
// LiveCommandChannel runs an `afterglow` command through FlareHeadless's catalog on a copy of the window's
// workspace and hands the copy back; the window becomes it, the command's undo step included.
extension FlareWorkspace {
    /// Becomes the workspace `ran` holds: this one with a live command applied.
    public mutating func takeLive(_ ran: FlareHeadless) {
        self = ran.workspace
    }
}
