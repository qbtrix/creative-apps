// BundleLayout.swift: where AfterGlow.app puts the launcher, the five apps
// and the four frameworks, and the run path each executable needs to find
// `Contents/Frameworks` (the bundle packet's contract slice). Takes the
// app's display name, so it needs nothing from SuiteApp; RO-1 checks that
// SuiteApp.bundlePath agrees.

public enum BundleLayout {
    /// The apps' display names, which are also their helper bundle folders.
    public static let apps = ["Flare", "Design", "Photo", "Library", "Halo"]

    /// The frameworks in `Contents/Frameworks`, in link order.
    public static let frameworks = ["SuiteUI", "SuiteModel", "SuiteShell", "CreativeEngines"]

    /// The executable's path inside AfterGlow.app; nil is the launcher.
    public static func executablePath(ofApp name: String?) -> String {
        guard let name else { return "Contents/MacOS/AfterGlow" }
        return "Contents/Helpers/\(name).app/Contents/MacOS/\(name)"
    }

    /// The `@executable_path` run path that reaches `Contents/Frameworks`;
    /// nil is the launcher.
    public static func runPath(ofApp name: String?) -> String {
        name == nil ? "@executable_path/../Frameworks" : "@executable_path/../../../../Frameworks"
    }
}
