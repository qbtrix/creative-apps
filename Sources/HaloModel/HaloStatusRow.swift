// HaloStatusRow.swift: the shapes Halo's viewer status row takes as its
// column narrows, widest first (HaloViewer tries them in this order and shows
// the first that fits). Every shape keeps the transport and the History
// button beside it (#4272, #4449), so a mouse can play, step and open History
// at the 880 pt window minimum. The transport leaves its pill for the row's
// leading edge first, so the layer count still shows at the journeys' 1000 pt
// window (#3925); then the layer count goes, then the zoom pill, then the
// timecode. The size pill always shows. Linux-safe: no UI imports.

/// One shape of the viewer's status row: which facts and controls it shows.
public struct HaloStatusRow: Sendable, Hashable {
    /// The layer count pill.
    public var layers: Bool
    /// The transport sits in the bar's trailing pill; false puts the bare
    /// transport at the row's leading edge, left of the pills.
    public var transportInBar: Bool
    /// The zoom pill.
    public var zoom: Bool
    /// The timecode pill.
    public var timecode: Bool
    /// The History button beside the transport.
    public var history: Bool

    public init(layers: Bool, transportInBar: Bool, zoom: Bool, timecode: Bool, history: Bool) {
        self.layers = layers
        self.transportInBar = transportInBar
        self.zoom = zoom
        self.timecode = timecode
        self.history = history
    }

    /// Everything, the transport and History in the bar's pills.
    public static let wide = HaloStatusRow(layers: true, transportInBar: true, zoom: true, timecode: true, history: true)
    /// The bare transport and History at the leading edge, every pill right, the layer count kept (#3925).
    public static let leadingLayers = HaloStatusRow(layers: true, transportInBar: false, zoom: true, timecode: true, history: true)
    /// As `leadingLayers` without the layer count (L5).
    public static let leading = HaloStatusRow(layers: false, transportInBar: false, zoom: true, timecode: true, history: true)
    /// The zoom pill drops before History or the timecode does (#4449).
    public static let leadingNoZoom = HaloStatusRow(layers: false, transportInBar: false, zoom: false, timecode: true, history: true)
    /// The last resort: the transport, History and the size pill.
    public static let bare = HaloStatusRow(layers: false, transportInBar: false, zoom: false, timecode: false, history: true)

    /// The shapes in the order the viewer tries them, widest first.
    public static let fallbacks: [HaloStatusRow] = [wide, leadingLayers, leading, leadingNoZoom, bare]

    /// The tooltip over the bar's zoom and size pills, naming only those shown.
    public var pillsHelp: String {
        zoom ? HaloComposition.viewerPillsHelp : "The composition size in pixels."
    }
}
