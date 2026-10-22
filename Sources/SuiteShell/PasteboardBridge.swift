// PasteboardBridge.swift (clipboard-interop CB-1 stub, CB-4c body): the one SuiteShell transport that writes
// SuitePasteboardCoding's items to the system pasteboard and reads what is offered there. It replaces the apps'
// own writers and their change-count polls. The writer is lifted from PhotoPasteboard's: every image is
// re-encoded by ImageIO from its pixels alone, so no GPS, maker note or other source metadata leaves the app,
// and a TIFF of the first image goes beside it for apps that read only TIFF. SVG goes as public.svg-image, an
// app's own layers as data under its type, a file as its file URL. PasteboardChangeWatch reads the change count
// when a menu starts tracking (the Edit menu opening) or a window becomes key: notifications, never a timer.
#if canImport(AppKit)
import AppKit
import ImageIO
import SuiteModel
import UniformTypeIdentifiers

/// The system pasteboard as `TypedData`.
@MainActor public struct PasteboardBridge {
    let pasteboard: NSPasteboard

    public init(_ pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }

    /// The image types the bridge re-encodes, so their metadata never crosses.
    static let imageTypes: Set<SuiteTypeID> = [.png, .jpeg, .heic]
    /// The public types the coder reads; the suite's own types are read by their prefix.
    static let publicTypes: Set<SuiteTypeID> = [.svg, .png, .jpeg, .heic, .plainText, .fileURL]

    /// Writes `items`: one clearContents, one write. Each type sits once per pasteboard item, so a second
    /// file URL starts a second item; the first image also goes as TIFF.
    public func write(_ items: [TypedData]) {
        let clean = items.compactMap(Self.outgoing)
        var slots: [[TypedData]] = []
        for rep in clean {
            if let i = slots.firstIndex(where: { !$0.contains { $0.type == rep.type } }) {
                slots[i].append(rep)
            } else {
                slots.append([rep])
            }
        }
        let objects = slots.map { reps in
            let item = NSPasteboardItem()
            for rep in reps { _ = item.setData(rep.data, forType: NSPasteboard.PasteboardType(rep.type.rawValue)) }
            return item
        }
        if let image = clean.first(where: { Self.imageTypes.contains($0.type) }),
            let tiff = Self.reencoded(image.data, as: UTType.tiff.identifier), let first = objects.first {
            _ = first.setData(tiff, forType: .tiff)
        }
        pasteboard.clearContents()
        if !objects.isEmpty { _ = pasteboard.writeObjects(objects) }
    }

    /// What the pasteboard offers now, in each item's own order: the suite's types and the public ones the
    /// coder reads, each read only when listed. A TIFF-only image is offered as PNG; images come back clean.
    public func offered() -> [TypedData] {
        var out: [TypedData] = []
        for item in pasteboard.pasteboardItems ?? [] {
            let types = item.types.map { SuiteTypeID(rawValue: $0.rawValue) }
            for type in types where Self.publicTypes.contains(type) || type.rawValue.hasPrefix(SuiteIdentity.prefix) {
                guard let data = item.data(forType: NSPasteboard.PasteboardType(type.rawValue)),
                    let rep = Self.incoming(TypedData(type: type, data: data))
                else { continue }
                out.append(rep)
            }
            if !types.contains(where: { Self.imageTypes.contains($0) }), let tiff = item.data(forType: .tiff),
                let png = Self.reencoded(tiff, as: UTType.png.identifier) {
                out.append(TypedData(type: .png, data: png))
            }
        }
        return out
    }

    /// The pasteboard's change count, read on menu open and window key, never on a timer.
    public var changeCount: Int { pasteboard.changeCount }

    /// A representation as it goes out: images stripped of metadata (dropped if they can't be), a file as a
    /// percent-encoded file URL.
    static func outgoing(_ rep: TypedData) -> TypedData? {
        if imageTypes.contains(rep.type) {
            return reencoded(rep.data, as: rep.type.rawValue).map { TypedData(type: rep.type, data: $0) }
        }
        guard rep.type == .fileURL else { return rep }
        let text = String(decoding: rep.data, as: UTF8.self)
        let path = text.hasPrefix("file://") ? String(text.dropFirst("file://".count)) : text
        let url = URL(fileURLWithPath: path.removingPercentEncoding ?? path)
        return TypedData(type: .fileURL, data: Data(url.absoluteString.utf8))
    }

    /// A representation as the coder reads it: images stripped of metadata, a file URL as `file://<path>`.
    static func incoming(_ rep: TypedData) -> TypedData? {
        if imageTypes.contains(rep.type) {
            return reencoded(rep.data, as: rep.type.rawValue).map { TypedData(type: rep.type, data: $0) }
        }
        guard rep.type == .fileURL else { return rep }
        guard let url = URL(dataRepresentation: rep.data, relativeTo: nil), url.isFileURL else { return nil }
        return TypedData(type: .fileURL, data: Data(("file://" + url.path(percentEncoded: false)).utf8))
    }

    /// The first image in `data` re-encoded as `type` from its pixels, keeping only its orientation; nil if
    /// ImageIO can't read or write it.
    static func reencoded(_ data: Data, as type: String) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type as CFString, 1, nil) else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let kept = props?[kCGImagePropertyOrientation].map { [kCGImagePropertyOrientation: $0] as CFDictionary }
        CGImageDestinationAddImage(destination, image, kept)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}

/// Calls `onChange` when the pasteboard changed since it last looked. It looks when any menu starts tracking
/// (the Edit menu opening) or a window becomes key, and when the Edit menu's delegate calls `check()` from
/// `menuNeedsUpdate`; it never polls, so an idle app reads nothing.
@MainActor public final class PasteboardChangeWatch: NSObject {
    let bridge: PasteboardBridge
    let onChange: @MainActor () -> Void
    private var seen: Int

    public init(_ bridge: PasteboardBridge = PasteboardBridge(), onChange: @escaping @MainActor () -> Void) {
        self.bridge = bridge
        self.onChange = onChange
        seen = bridge.changeCount
        super.init()
        for name in [NSWindow.didBecomeKeyNotification, NSMenu.didBeginTrackingNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(heard(_:)), name: name, object: nil)
        }
    }

    @objc private func heard(_ note: Notification) { check() }

    /// Reads the change count once and calls `onChange` if it moved.
    public func check() {
        let count = bridge.changeCount
        guard count != seen else { return }
        seen = count
        onChange()
    }
}
#endif
