// HaloKeyMove+Kernel.swift (key-editing KE-1 stubs, KE-4 bodies): moving the
// picked keys as an adapter over the kernel's `KeyRules.moveKeys`, one
// "Move Keyframes" step per drag through `edit(coalesceKey:)`. On the stubs a
// move and a drag's end do nothing, and the help says the move waits on KE-4.
// Linux-safe: no UI imports.

extension HaloProject {
    /// Moves every picked key by `frames` since the last call; calls with the
    /// same `dragStart` fold into one step (KE-4).
    public mutating func moveKeys(by frames: Int, dragStart: Int) {}

    /// Ends the key drag, so the next move is its own step (KE-4).
    public mutating func endKeyDrag() {}

    /// Nil when the picked keys can move; otherwise why not.
    public var moveKeysHelp: String? { "Not built yet (KE-4)." }
}
