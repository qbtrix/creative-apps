// PhotoFacetsTests.swift: PhotoWorkspace's facets (PhotoFacets.swift). Every
// stored field of the workspace is in exactly one facet's list, read off the
// struct itself, so a new field fails here until it is placed; and an edit
// moves only the facets that own what it changed (a brush-size step only
// `toolOptions`, a layer pick only `document`), which is what lets a window
// re-run only the views that read them. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoFacetsTests {
    @Test func everyFieldBelongsToExactlyOneFacet() throws {
        let workspace = try PhotoWorkspace.fixture(.layered)
        let fields = Mirror(reflecting: workspace).children.compactMap(\.label)
        #expect(!fields.isEmpty)
        let listed = PhotoWorkspace.facetFields.values.flatMap { $0 }
        for field in fields {
            let owners = PhotoWorkspace.facetFields.filter { $0.value.contains(field) }.map(\.key)
            #expect(owners.count == 1, "\(field) is in \(owners.count) facets: \(owners)")
        }
        #expect(Set(listed).subtracting(fields).isEmpty, "listed but not fields: \(Set(listed).subtracting(fields))")
        #expect(listed.count == Set(listed).count, "a field is listed twice")
        #expect(Set(PhotoWorkspace.facetFields.keys) == Set(PhotoFacet.allCases))
    }

    @Test func aBrushSizeStepMovesOnlyToolOptions() throws {
        var workspace = try PhotoWorkspace.fixture(.layered)
        workspace.selectTool(.brush)
        let before = workspace.facets
        workspace.setToolOption(.size(before.toolOptions.brush.size + 7))
        #expect(Self.changed(before, workspace.facets) == [.toolOptions])
    }

    @Test func aLayerPickMovesOnlyTheDocument() throws {
        var workspace = try PhotoWorkspace.fixture(.layered)
        let other = try #require(workspace.layers.map(\.id).first { $0 != workspace.selectedLayerID })
        let before = workspace.facets
        workspace.pickLayer(other, .replace)
        #expect(Self.changed(before, workspace.facets) == [.document])
    }

    @Test func aToolSwitchMovesOnlyTheTool() throws {
        var workspace = try PhotoWorkspace.fixture(.layered)
        let before = workspace.facets
        workspace.selectTool(.eraser)
        #expect(Self.changed(before, workspace.facets) == [.tool])
    }

    @Test func eachFacetFollowsItsFields() throws {
        var workspace = try PhotoWorkspace.fixture(.layered)
        var before = workspace.facets
        workspace.adjust(.exposure(0.4))
        #expect(Self.changed(before, workspace.facets) == [.adjust, .history, .canvas])

        before = workspace.facets
        workspace.selectAll()
        #expect(Self.changed(before, workspace.facets).contains(.canvas))
        #expect(!Self.changed(before, workspace.facets).contains(.toolOptions))

        before = workspace.facets
        workspace.undo()
        #expect(Self.changed(before, workspace.facets).contains(.history))

        var unknown = try #require(PhotoWorkspace.launch(PhotoLaunchOptions(arguments: ["-PhotoFixture", "nope"])))
        before = unknown.facets
        unknown.clearStatus()
        #expect(Self.changed(before, unknown.facets) == [.status])
    }

    /// The facets that differ between `a` and `b`.
    static func changed(_ a: PhotoFacets, _ b: PhotoFacets) -> Set<PhotoFacet> {
        var out: Set<PhotoFacet> = []
        if a.document != b.document { out.insert(.document) }
        if a.tool != b.tool { out.insert(.tool) }
        if a.toolOptions != b.toolOptions { out.insert(.toolOptions) }
        if a.adjust != b.adjust { out.insert(.adjust) }
        if a.history != b.history { out.insert(.history) }
        if a.status != b.status { out.insert(.status) }
        if a.canvas != b.canvas { out.insert(.canvas) }
        if a.file != b.file { out.insert(.file) }
        return out
    }
}
