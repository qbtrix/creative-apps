// AreaSelectCommands.swift (area-selection AR-1): the declarations the tests compile against; the specs follow.

/// A document with an area selection: an app's workspace conforms in its `<X>Area+Kernel.swift`.
public protocol AreaSelectTarget: Sendable {
    /// Why nothing can be selected now (no document, no layer); nil when it can.
    var areaHelp: String? { get }
    /// The selection as the steps that make it; `.empty` when nothing is selected.
    var areaRecipe: AreaRecipe { get }
    /// The recipe before the last Deselect or replace, for Reselect; nil when there was none.
    var lastAreaRecipe: AreaRecipe? { get }
    /// Sets the selection's recipe as one undo step.
    mutating func setAreaRecipe(_ recipe: AreaRecipe) throws
}

/// The area select commands and the runner that takes them through a catalog.
public enum AreaSelectCommands {
    /// The area commands on `target`. Declaration only: none yet.
    public static func specs<T: AreaSelectTarget>(_ target: T.Type) -> [CommandSpec<T>] { [] }
    /// Runs the area command `id` with `params` on `target`. Declaration only: does nothing.
    public static func run<T: AreaSelectTarget>(_ id: String, _ params: JSONValue, on target: inout T) throws {}
}
