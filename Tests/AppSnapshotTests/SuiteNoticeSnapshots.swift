// SuiteNoticeSnapshots.swift: the gallery's `notice` page, SuiteUI's
// InlineNotice in each kind: success with a close, a warning with an action,
// a disabled close and a detail line, an error with an action, plain info,
// and the bare form in a padded column, in Light and Dark:
// suiteui-notice-{light,dark}.png. macOS only.
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteNoticeSnapshots {
    @Test func everyKindWithAndWithoutAnAction() throws {
        #expect(SuiteGallery.resolve("notice") == .page("notice"))
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(GalleryNoticePage(), name: "suiteui-notice-\(scheme.name)", scheme: scheme)
        }
    }
}
