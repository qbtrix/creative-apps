// SuiteUnsavedSheetSnapshots.swift (adopt-kernel-unsaved-prompt UP-4): suiteui-unsaved-sheet-light and -dark. The
// gallery's fake document ("Poster", edited) in a titled 1440 x 900 window behind `.unsavedChangesGuard`; a close
// puts the guard's sheet up (the kernel's words, Save, Don't Save and Cancel), and the PNG is the window's content
// with the sheet drawn over its top centre, where AppKit attaches it. Cancel takes the sheet down again, so the
// window is left open and dirty. UnsavedSheetFixture is shared with RenderBudgetUnsavedGuardTests; nested in
// BodyCountSuites, since its document counts the bodies that test reads. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct SuiteUnsavedSheetSnapshots {
        @Test(.timeLimit(.minutes(1))) func sheet() async throws {
            for scheme in [ColorScheme.light, .dark] {
                let fixture = UnsavedSheetFixture()
                let window = fixture.window(scheme: scheme)
                defer { window.close() }
                window.performClose(nil)
                let up = await UnsavedSheetFixture.eventually { window.attachedSheet != nil }
                try #require(up, "a close of the dirty fake document put no sheet up")
                let sheet = try #require(window.attachedSheet)
                for answer in UnsavedPrompt.answers {
                    let button = UnsavedSheetFixture.button(answer, in: window)
                    #expect(button?.title == UnsavedPrompt.title(of: answer), "the sheet has no \(answer) button")
                }
                sheet.appearance = window.appearance
                let image = try #require(Self.composite(window, sheet: sheet), "the sheet didn't draw")
                try Self.write(image, name: "suiteui-unsaved-sheet-\(scheme.name)")
                UnsavedSheetFixture.button(.cancel, in: window)?.performClick(nil)
                _ = await UnsavedSheetFixture.eventually { window.attachedSheet == nil }
                #expect(window.isVisible, "Cancel closed the window")
            }
        }

        /// The window's content at 1440 x 900, one pixel per point, with `sheet`'s content over its top centre.
        static func composite(_ window: NSWindow, sheet: NSWindow) -> NSBitmapImageRep? {
            guard let content = window.contentView, let card = sheet.contentView else { return nil }
            content.layoutSubtreeIfNeeded()
            card.layoutSubtreeIfNeeded()
            let size = UnsavedSheetFixture.size
            guard let image = bitmap(size), let cardImage = bitmap(card.bounds.size) else { return nil }
            content.cacheDisplay(in: content.bounds, to: image)
            card.cacheDisplay(in: card.bounds, to: cardImage)
            guard let context = NSGraphicsContext(bitmapImageRep: image) else { return nil }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            let origin = CGPoint(x: (size.width - card.bounds.width) / 2, y: size.height - card.bounds.height)
            cardImage.draw(in: CGRect(origin: origin, size: card.bounds.size))
            NSGraphicsContext.restoreGraphicsState()
            return image
        }

        private static func bitmap(_ size: CGSize) -> NSBitmapImageRep? {
            guard size.width >= 1, size.height >= 1 else { return nil }
            let image = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                bitsPerPixel: 0)
            image?.size = size
            return image
        }

        /// Writes `image` as `<package root>/.build/snapshots/<name>.png`, as `snapshot(_:name:scheme:)` does.
        private static func write(_ image: NSBitmapImageRep, name: String) throws {
            #expect(image.pixelsWide == 1440 && image.pixelsHigh == 900, "\(name) is \(image.pixelsWide)x\(image.pixelsHigh)")
            guard let png = image.representation(using: .png, properties: [:]) else { throw SnapshotError.encode(name) }
            let folder = try packageRoot().appending(path: ".build/snapshots")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try png.write(to: folder.appending(path: "\(name).png"))
        }
    }
}

/// The gallery's fake document behind the guard: "Poster", edited, and a save that lands.
@MainActor final class UnsavedSheetFixture {
    static let size = CGSize(width: 1440, height: 900)
    static let prefix = "suite.gallery"
    var dirty = true

    var hooks: UnsavedHooks {
        UnsavedHooks(
            idPrefix: Self.prefix, documentName: { "Poster" }, isDirty: { self.dirty },
            save: {
                self.dirty = false
                return true
            })
    }

    /// A titled, closable window far off every screen, hosting the guarded document in `scheme`.
    func window(scheme: ColorScheme) -> NSWindow {
        _ = TestDefaults.registered
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: Self.size), styleMask: [.titled, .closable], backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = NSHostingView(
            rootView: UnsavedSheetDocument()
                .environment(\.colorScheme, scheme)
                .environment(\.suiteSnapshotRendering, true)
                .unsavedChangesGuard(hooks))
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        return window
    }

    /// The sheet's button for `answer` (`suite.gallery.close.<answer>`), nil when no sheet shows it.
    static func button(_ answer: UnsavedPrompt.Answer, in window: NSWindow) -> NSButton? {
        let identifier = UnsavedGuard.identifier(answer, prefix: prefix)
        guard let root = window.attachedSheet?.contentView else { return nil }
        var views = [root]
        while let view = views.popLast() {
            if let button = view as? NSButton, button.accessibilityIdentifier() == identifier { return button }
            views.append(contentsOf: view.subviews)
        }
        return nil
    }

    /// Turns the run loop until `condition` holds, at most `seconds`; whether it held.
    static func eventually(_ seconds: Double = 2, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition() {
            guard Date() < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return true
    }
}

/// The fake document's window: its name and "Edited" over an empty canvas. Counts its bodies in debug.
struct UnsavedSheetDocument: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Poster").font(SuiteFont.sectionCaps)
            Text("Edited").foregroundStyle(SuiteColor.secondaryText)
            CanvasSurface(artboard: CGSize(width: 1600, height: 1000))
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.windowBackground)
    }
}
#endif
