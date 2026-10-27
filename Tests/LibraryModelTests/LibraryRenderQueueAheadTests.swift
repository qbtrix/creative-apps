// LibraryRenderQueueAheadTests.swift: RenderQueue decodes the loupe's
// neighbours behind its render, one at a time, a waiting render always first,
// and a newer step's neighbours replace an older step's pending ones
// (large-catalog LG-6, #3109). Deterministic: a held job waits on a signal,
// never a sleep. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import LibraryModel
import Testing

/// What ran, in order: renders as "r<token>", decodes as the photo's id.
private actor AheadLog {
    private(set) var ran: [String] = []
    func add(_ entry: String) { ran.append(entry) }
}

/// A one-shot signal: `wait()` returns once `fire()` has been called.
private struct Gate: Sendable {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() { (stream, continuation) = AsyncStream.makeStream(of: Void.self) }

    func fire() { continuation.yield(()) }

    func wait() async {
        for await _ in stream { return }
    }
}

private func photo(_ id: String) -> PhotoItem {
    PhotoItem(id: id, name: id, captureDate: .distantPast, color: Color3(0.5, 0.5, 0.5))
}

private func ahead(_ ids: [String], _ log: AheadLog) -> RenderQueue.Ahead {
    RenderQueue.Ahead(ids.map(photo)) { await log.add($0.id) }
}

@Test func theNeighboursDecodeAfterTheRender() async {
    let queue = RenderQueue()
    let log = AheadLog()
    await queue.submit(token: 1, prefetching: ahead(["a", "c"], log)) { await log.add("r1") }
    #expect(await log.ran == ["r1", "a", "c"])
}

@Test func aNewStepDropsTheOldStepsNeighbours() async {
    let queue = RenderQueue()
    let log = AheadLog()
    let started = Gate(), release = Gate()
    let first = Task {
        await queue.submit(token: 1) {
            await log.add("r1")
            started.fire()
            await release.wait()
        }
    }
    await started.wait()
    // Two steps while render 1 runs: the second's render and neighbours replace the first's.
    await queue.submit(token: 2, prefetching: ahead(["a", "c"], log)) { await log.add("r2") }
    await queue.submit(token: 3, prefetching: ahead(["b", "d"], log)) { await log.add("r3") }
    release.fire()
    await first.value
    #expect(await log.ran == ["r1", "r3", "b", "d"])
}

@Test func aStepMidPrefetchRendersBeforeTheRestAndDropsIt() async {
    let queue = RenderQueue()
    let log = AheadLog()
    let started = Gate(), release = Gate()
    let held = RenderQueue.Ahead([photo("a"), photo("c")]) { item in
        await log.add(item.id)
        if item.id == "a" {
            started.fire()
            await release.wait()
        }
    }
    let first = Task { await queue.submit(token: 1, prefetching: held) { await log.add("r1") } }
    await started.wait()
    // Decoding "a": the step to "c" renders next, and the old "c" decode never runs.
    await queue.submit(token: 2, prefetching: ahead(["d"], log)) { await log.add("r2") }
    release.fire()
    await first.value
    #expect(await log.ran == ["r1", "a", "r2", "d"])
}

@Test func aRenderWithNoNeighboursKeepsThePendingOnes() async {
    let queue = RenderQueue()
    let log = AheadLog()
    let started = Gate(), release = Gate()
    let first = Task {
        await queue.submit(token: 1, prefetching: ahead(["a", "c"], log)) {
            await log.add("r1")
            started.fire()
            await release.wait()
        }
    }
    await started.wait()
    // A develop drag's render on the same photo: its neighbours still decode after it.
    await queue.submit(token: 2) { await log.add("r2") }
    release.fire()
    await first.value
    #expect(await log.ran == ["r1", "r2", "a", "c"])
}
