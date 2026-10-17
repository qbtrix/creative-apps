// FlareTimelineEdit.swift: the timeline strip with key editing (inspector-timeline IT-7), `selectedKeys` picked.
// A key press selects it (Shift adds, Command toggles); a drag sends `.moveKeys` per frame step keyed by its start,
// one merged "Move Keyframe", then `.endKeyDrag`; a refused step moves nothing and sets `timelineError`. Delete and
// the context menu (a right press selects the key) delete keys, insert or remove a frame and add or remove the label
// at the playhead, disabled by `FlareWindow.timelineHelp`. Labels draw in a row on the ruler, only when one exists.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareTimelineEdit: View {
    let model: FlareWorkspace
    let perform: @MainActor (FlareIntent) -> Void
    @State private var dragStart: Int?
    @State private var namingLabel = false
    @State private var labelName = ""

    var body: some View {
        let rows = model.timelineRows, labels = model.timelineLabels
        let lastFrame = max(model.timelineFrames - 1, 0)
        return GeometryReader { proxy in
            let frameWidth = FlareTimeline.laneWidth(strip: proxy.size.width) / CGFloat(max(lastFrame, 1))
            VStack(alignment: .leading, spacing: 0) {
                if !labels.isEmpty { labelMarks(labels, frameWidth: frameWidth) }
                strip(rows, lastFrame: lastFrame, frameWidth: frameWidth)
            }
        }
        .frame(height: (labels.isEmpty ? .zero : SuiteSize.timelineRuler) + SuiteSize.timelineRuler
            + SuiteSize.timelineLane * CGFloat(rows.count))
        .popover(isPresented: $namingLabel) { labelField }
    }

    private func strip(_ rows: [TimelineRow], lastFrame: Int, frameWidth: CGFloat) -> some View {
        let picked = Dictionary(grouping: model.selectedKeys.filter { $0.property == nil }, by: \.layerID)
        let tracks = rows.map { row in
            TimelineTrack(
                id: row.layerID, name: row.name, keys: row.keyFrames.map { TimelineKey(frame: $0, shape: .linear) },
                pickedFrames: Set((picked[row.layerID] ?? []).map(\.frame)),
                isSelected: row.layerID == model.selectedTimelineRowID)
        }
        return TimelineStrip(
            tracks: tracks, duration: lastFrame, frameWidth: frameWidth, playhead: model.currentFrame,
            onScrub: { perform(.timeline(.scrub(frame: $0))) },
            onSelectKeyframe: { id, _ in perform(.layers(.select(id: id))) },
            onSelectTrack: { perform(.layers(.select(id: $0))) },
            onPickKeyframe: { id, frame, mode in pick(layerID: id, frame: frame, mode: mode) },
            onMoveKeyframes: { delta in
                let start = dragStart ?? model.selectedKeys.map(\.frame).min() ?? 0
                dragStart = start
                perform(.timeline(.moveKeys(by: delta, dragStart: start)))
            },
            onEndKeyDrag: {
                dragStart = nil
                perform(.timeline(.endKeyDrag))
            })
            .accessibilityIdentifier("flare.timeline.track")
            .onKeyPress(keys: [.delete, .deleteForward]) { _ in
                guard FlareWindow.timelineHelp(.removeKeys, in: model) == nil else { return .ignored }
                perform(.timeline(.removeKeys))
                return .handled
            }
            .contextMenu { menuItems }
    }

    /// A press on a key: plain selects it alone, Shift adds it, Command toggles it. A bed press keeps the selection.
    private func pick(layerID: String, frame: Int?, mode: PickMode) {
        guard let frame else { return }
        let key = KeyRef(layerID: layerID, property: nil, frame: frame)
        guard mode != .extend || !model.selectedKeys.contains(key) else { return }
        perform(.timeline(.selectKey(layerID: layerID, property: nil, frame: frame, extending: mode != .replace)))
    }

    @ViewBuilder private var menuItems: some View {
        item("Delete Keyframe", .removeKeys)
        Divider()
        item("Insert Frame", .insertFrames(1))
        item("Remove Frame", .removeFrames(1))
        Divider()
        let label = model.timelineLabels[model.currentFrame]
        Button("Add Label…") {
            labelName = label ?? ""
            namingLabel = true
        }
        .disabled(model.document == nil)
        .help(model.document == nil ? "Open an animation to label its frames." : "Name a label at the playhead.")
        Button("Remove Label") { perform(.timeline(.setLabel(nil))) }
            .disabled(label == nil)
            .help(label == nil ? "No label at the playhead." : "Remove Label")
    }

    private func item(_ title: String, _ intent: FlareIntent.Timeline) -> some View {
        let reason = FlareWindow.timelineHelp(intent, in: model)
        return Button(title) { perform(.timeline(intent)) }.disabled(reason != nil).help(reason ?? title)
    }

    /// The label's name: Return or Add Label sets it at the playhead.
    private var labelField: some View {
        let name = labelName.trimmingCharacters(in: .whitespaces)
        let add: @MainActor () -> Void = {
            namingLabel = false
            perform(.timeline(.setLabel(name)))
        }
        return VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            TextField("Label at frame \(model.currentFrame)", text: $labelName)
                .accessibilityIdentifier("flare.timeline.labelName")
                .onSubmit { if !name.isEmpty { add() } }
            Button("Add Label", action: add).disabled(name.isEmpty)
        }
        .padding(SuiteSpacing.m)
    }

    /// Each label as a flag and its name at its frame's x in the lanes.
    private func labelMarks(_ labels: [Int: String], frameWidth: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            ForEach(labels.keys.sorted(), id: \.self) { frame in
                let name = labels[frame] ?? ""
                Label(name, systemImage: "flag.fill")
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.textPrimary)
                    .fixedSize()
                    .offset(x: SuiteSize.timelineLabelColumn + 1 + SuiteSpacing.s + CGFloat(frame) * frameWidth)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Label \(name) at frame \(frame)")
                    .accessibilityIdentifier("flare.timeline.label")
            }
        }
        .frame(maxWidth: .infinity, minHeight: SuiteSize.timelineRuler, alignment: .leading)
    }
}
