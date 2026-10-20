#!/usr/bin/env bash
# Tests/sample_surfaces/test_sample_surfaces.sh: fixture test for
# scripts/sample-surfaces. A call graph shaped like /usr/bin/sample writes it:
# the main thread's 1000 samples hold 600 under RB::SurfacePool::alloc (with an
# IOSurfaceCreate nested under it, which must not count again) and 100 under a
# CA commit's IOSurfaceCreate, so 70% is over the default 20% limit and exits
# 1; a worker thread's IOSurfaceCreate never counts. The same report passes
# with --max-percent 75, a main thread headed "Main Thread" (several queues)
# counts the same, and a report with no main thread exits 2.
# Needs bash and python3.
#
# Run: bash Tests/sample_surfaces/test_sample_surfaces.sh   (exit 0 = all pass)
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

cat >"$tmp/sample.txt" <<'TXT'
Analysis of sampling Photo (pid 4242) every 1 millisecond
Process:         Photo [4242]

Call graph:
    1000 Thread_100   DispatchQueue_1: com.apple.main-thread  (serial)
    + 1000 start  (in dyld) + 6992  [0x1]
    +   1000 NSApplicationMain  (in AppKit) + 880  [0x2]
    +     700 CA::Transaction::commit()  (in QuartzCore) + 600  [0x3]
    +     ! 600 RB::SurfacePool::alloc(RB::Device&, RB::Surface::Format, unsigned long, unsigned long)  (in RenderBox) + 300  [0x4]
    +     ! : 600 IOSurfaceCreate  (in IOSurface) + 120  [0x5]
    +     ! 100 CA::Render::Shmem::new_bitmap  (in QuartzCore) + 40  [0x6]
    +     !   100 IOSurfaceCreate  (in IOSurface) + 120  [0x5]
    +     300 __CFRunLoopRun  (in CoreFoundation) + 1188  [0x7]
    +       300 mach_msg2_trap  (in libsystem_kernel.dylib) + 8  [0x8]
    500 Thread_200
    + 500 thread_start  (in libsystem_pthread.dylib) + 8  [0x9]
    +   500 IOSurfaceCreate  (in IOSurface) + 120  [0x5]

Total number in stack (recursive counted multiple, when >=5):

Sort by top of stack, same collapsed (when >= 5):
        IOSurfaceCreate  (in IOSurface)        1200
        mach_msg2_trap  (in libsystem_kernel.dylib)        300

Binary Images:
TXT

out=$(python3 "$root/scripts/sample-surfaces" "$tmp/sample.txt"); status=$?
check "70% under surface allocation exits 1" '[[ $status -eq 1 ]]'
check "it counts 700 of 1000 main-thread samples, nested frames once" \
  '[[ "$out" == *"main thread: 1000 samples, 700 under surface allocation (70.0%, limit 20%) OVER"* ]]'
check "it names the top matched frame first" '[[ "$(printf "%s\n" "$out" | sed -n 2p)" == *"600  RB::SurfacePool::alloc"* ]]'
check "it prints the top of stack" '[[ "$out" == *"top of stack: IOSurfaceCreate (in IOSurface) 1200"* ]]'
python3 "$root/scripts/sample-surfaces" "$tmp/sample.txt" --max-percent 75 >/dev/null; status=$?
check "the same report passes under a 75% limit" '[[ $status -eq 0 ]]'
sed 's/Thread_100   DispatchQueue_1: com.apple.main-thread  (serial)/Thread_100: Main Thread   DispatchQueue_<multiple>/' "$tmp/sample.txt" >"$tmp/multi.txt"
out=$(python3 "$root/scripts/sample-surfaces" "$tmp/multi.txt")
check "a main thread headed Main Thread counts too" '[[ "$out" == *"main thread: 1000 samples, 700 under"* ]]'
sed 's/DispatchQueue_1: com.apple.main-thread  (serial)//' "$tmp/sample.txt" >"$tmp/nomain.txt"
python3 "$root/scripts/sample-surfaces" "$tmp/nomain.txt" >/dev/null; status=$?
check "a report with no main thread exits 2" '[[ $status -eq 2 ]]'
exit $fail
