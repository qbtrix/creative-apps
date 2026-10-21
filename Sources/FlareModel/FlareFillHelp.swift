// FlareFillHelp.swift (gradient-fill FG-2): why the inspector's FILL switch and gradient editor can't act. With no
// shape to paint it is `fillHelp`'s reason; while Flare's catalog has no fill commands (FG-5 adds them) it says the
// editing isn't built, so the controls show disabled with a reason instead of refusing on every click.
import SuiteKernel

extension FlareWorkspace {
    /// The reason fill editing isn't built yet; FG-5 retires it.
    public static let fillEditNotBuilt = "Editing a fill's type and gradient isn't built yet."

    /// Why a fill gesture can't run now; nil when it can.
    public var fillEditHelp: String? {
        if let help = fillHelp { return help }
        return Self.catalog.spec(GradientIntent.type(.solid).command.id) == nil ? Self.fillEditNotBuilt : nil
    }
}
