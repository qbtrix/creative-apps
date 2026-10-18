// LibraryRenderQueueTests.swift: RenderQueue runs one loupe render at a time
// and keeps only the latest waiting one (loupe-viewport LV-3). Deterministic:
// job 1 holds until the test releases it, and every wait is on a signal, never
// a sleep. Runs on Linux and macOS.
import LibraryModel
import Testing

/// Records which tokens ran, in order, and the most jobs running at once.
private actor RunLog {
    private(set) var ran: [Int] = []
    private(set) var running = 0
    private(set) var maxRunning = 0

    func enter(_ token: Int) {
        ran.append(token)
        running += 1
        maxRunning = max(maxRunning, running)
    }

    func exit() { running -= 1 }
}

/// A one-shot signal: `wait()` returns once `fire()` has been called.
private struct Signal: Sendable {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream(of: Void.self)
    }

    func fire() { continuation.yield(()) }

    func wait() async {
        for await _ in stream { return }
    }
}

@Test func onlyTheLatestWaitingRenderRunsAfterTheRunningOne() async {
    let queue = RenderQueue()
    let log = RunLog()
    let started = Signal()
    let release = Signal()

    let first = Task {
        await queue.submit(token: 1) {
            await log.enter(1)
            started.fire()
            await release.wait()
            await log.exit()
        }
    }
    await started.wait()
    // Job 1 is running: these two only wait, and 3 replaces 2.
    await queue.submit(token: 2) {
        await log.enter(2)
        await log.exit()
    }
    await queue.submit(token: 3) {
        await log.enter(3)
        await log.exit()
    }
    #expect(await log.ran == [1])
    release.fire()
    await first.value

    #expect(await log.ran == [1, 3])
    #expect(await log.maxRunning == 1)
}

@Test func anIdleQueueRunsASubmittedRenderAtOnce() async {
    let queue = RenderQueue()
    let log = RunLog()
    await queue.submit(token: 7) {
        await log.enter(7)
        await log.exit()
    }
    await queue.submit(token: 8) {
        await log.enter(8)
        await log.exit()
    }
    #expect(await log.ran == [7, 8])
    #expect(await log.maxRunning == 1)
}
