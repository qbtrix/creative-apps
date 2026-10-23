// PhotoBrushKeysTests.swift (brush-keys BK-7): Photo's brush keys through the kernel's BrushKeyCommands. A step acts
// on the active tool's settings only (the eraser keeps its own), the options show the new value, a key with no brush
// tool is refused, and with the Move tool a digit sets every selected layer's opacity as one undo step. Runs on Linux
// and macOS.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoBrushKeysTests {
    let catalog = PhotoWorkspace.catalog

    /// A white image with the Brush picked at 20 px.
    func brushAt20() throws -> PhotoWorkspace {
        var workspace = try whiteImage(64, 64)
        workspace.selectTool(.brush)
        workspace.setToolOption(.size(20))
        return workspace
    }

    @Test func sizeUpOnA20PxBrushGives25() throws {
        var workspace = try brushAt20()
        _ = try catalog.run("brush.size-up", params: .object([:]), on: &workspace)
        #expect(workspace.toolOptions.size == 25)
        #expect(workspace.brushCursorDiameter == 25)
        _ = try catalog.run("brush.size-up", params: .object([:]), on: &workspace)
        #expect(workspace.toolOptions.size == 30)
        _ = try catalog.run("brush.size-down", params: .object([:]), on: &workspace)
        #expect(workspace.toolOptions.size == 25)
    }

    @Test func hardnessAndOpacityShowInTheOptions() throws {
        var workspace = try brushAt20()
        workspace.setToolOption(.hardness(percent: 50))
        _ = try catalog.run("brush.hardness-up", params: .object([:]), on: &workspace)
        #expect(workspace.toolOptions.hardnessPercent == 75)
        _ = try catalog.run("brush.hardness-down", params: .object([:]), on: &workspace)
        _ = try catalog.run("brush.hardness-down", params: .object([:]), on: &workspace)
        #expect(workspace.toolOptions.hardnessPercent == 25)
        _ = try catalog.run("brush.set-opacity", params: .object(["percent": .number(45)]), on: &workspace)
        #expect(workspace.toolOptions.opacityPercent == 45)
        #expect(workspace.historySteps.count == 1, "brush settings are not document edits")
    }

    @Test func aStepActsOnTheActiveToolOnly() throws {
        var workspace = try brushAt20()
        workspace.selectTool(.eraser)
        workspace.setToolOption(.size(40))
        _ = try catalog.run("brush.size-up", params: .object([:]), on: &workspace)
        #expect(workspace.eraserOptions.size == 45)
        #expect(workspace.brushOptions.size == 20)
        #expect(workspace.activeBrush?.size == 45)
    }

    @Test func noBrushToolRefusesTheSteps() throws {
        var workspace = try brushAt20()
        for tool in [PhotoTool.move, .marquee, .crop, .text] {
            workspace.selectTool(tool)
            #expect(workspace.activeBrush == nil, "\(tool)")
            #expect(catalog.availability("brush.size-up", on: workspace).why == BrushKeyCommands.noBrushHelp)
        }
        #expect(throws: CatalogError.self) { try catalog.run("brush.size-up", params: .object([:]), on: &workspace) }
        #expect(PhotoWorkspace().activeBrush == nil)
    }

    @Test func digitsWithMoveSetTheSelectedLayersAsOneStep() throws {
        var workspace = try fourLayers()
        let (one, two, three) = (layerID(workspace, "Layer 1"), layerID(workspace, "Layer 2"), layerID(workspace, "Layer 3"))
        workspace.layerSelection.replace([one, three])
        workspace.selectTool(.move)
        let before = workspace.layers, steps = workspace.historySteps.count
        var digits = OpacityDigits()
        let action = BrushKeys.action(for: "5", shift: false, settings: BrushSettings(), brushActive: workspace.activeBrush != nil,
                                      digits: &digits, now: 0)
        #expect(action == .layerOpacity(50))
        _ = try catalog.run("layer.set-opacity", params: .object(["percent": .number(50)]), on: &workspace)
        #expect(workspace.layers.first { $0.id == one }?.opacity == 0.5)
        #expect(workspace.layers.first { $0.id == three }?.opacity == 0.5)
        #expect(workspace.layers.first { $0.id == two }?.opacity == 1)
        #expect(workspace.historySteps.count == steps + 1)
        workspace.undo()
        #expect(workspace.layers == before)
    }

    @Test func layerOpacityNeedsAnImage() {
        #expect(PhotoWorkspace().layerOpacityHelp == PhotoWorkspace.noImage)
        #expect(catalog.availability("layer.set-opacity", on: PhotoWorkspace()).why == PhotoWorkspace.noImage)
    }

    @Test func aKeyMapsToTheOptionEdit() {
        #expect(PhotoWorkspace.toolOptionEdit(for: .brush(.size(30))) == .size(30))
        #expect(PhotoWorkspace.toolOptionEdit(for: .brush(.hardness(75))) == .hardness(percent: 75))
        #expect(PhotoWorkspace.toolOptionEdit(for: .brush(.opacity(45))) == .opacity(percent: 45))
        #expect(PhotoWorkspace.toolOptionEdit(for: .layerOpacity(45)) == nil)
    }

    @Test func aMenuStepNamesTheNextValue() throws {
        let workspace = try brushAt20()
        #expect(workspace.brushStep("brush.size-up") == .brush(.size(25)))
        #expect(workspace.brushStep("brush.size-down") == .brush(.size(15)))
        #expect(workspace.brushStep("brush.hardness-down") == .brush(.hardness(75)))
        #expect(workspace.brushStep("layer.new") == nil)
        #expect(PhotoWorkspace().brushStep("brush.size-up") == nil)
    }
}
