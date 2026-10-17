// LaunchArguments.swift: the launch arguments a cold-launched app gets from a
// switch (blueprint 2.6, journey launch arguments). An app takes the flags
// named for it ("-DesignSaveTo x" goes to Design only) and the suite-wide
// ones; every other flag stays behind. A flag takes the next token as its
// value when that token doesn't start with "-". Foundation free, Linux-safe,
// Sendable.

public enum LaunchArguments {
    /// Flags every suite app takes, whatever its name.
    static let suiteWide: Set<String> = ["-SuiteSupportDir", "-SuitePerfProbe", "-SuiteFixtureDocuments"]

    public static func forward(_ args: [String], to app: SuiteApp) -> [String] {
        var forwarded: [String] = []
        var index = 0
        while index < args.count {
            let hasValue = index + 1 < args.count && !args[index + 1].hasPrefix("-")
            let width = hasValue ? 2 : 1
            if keeps(args[index], for: app) { forwarded += args[index..<index + width] }
            index += width
        }
        return forwarded
    }

    private static func keeps(_ flag: String, for app: SuiteApp) -> Bool {
        suiteWide.contains(flag) || flag.hasPrefix("-" + app.displayName)
    }
}
