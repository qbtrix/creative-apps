// LauncherRouter.swift: the launcher's app delegate, adapted in AfterGlowApp.
// An empty stub for now. Switching (SW-3b) owns this file from wave 2 and
// makes it the router that forwards opened documents to the embedded apps;
// services wire in through LauncherRouter+Services.swift (home, HM-2a), not
// here and not in AfterGlowApp.swift.
import AppKit

final class LauncherDelegate: NSObject, NSApplicationDelegate {}
