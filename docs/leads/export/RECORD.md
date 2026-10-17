# export lead record

Issue: #1554 · Packet: docs/blueprints/library/features/export.md
Run: act-1a147b718b0-qox5 · Session: resumed after worker restart · Started: 2026-10-17T03:07Z
Stage: 2 plan
Base: 82ac50553324ea359ca4b75c5d495fc812445cde (origin/dev)
Next: supervisor answers base (dev vs main); then plan waves against the current origin/dev and build the contract slice
| EX-b | File > Export sheet, real JPEG | EX-4..EX-6 | J7 | EX-a | yes | 0 | planned | - | - |
| EX-c | PNG/TIFF/HEIC formats | EX-7..EX-8 | J7F | EX-a; EX-b | yes | 0 | planned | - | - |
| EX-d | name templates, presets | EX-9..EX-11 | J7N | EX-a; EX-b | yes | 0 | planned | - | - |
| EX-e | progress, cancel, failures, cropped export | EX-12..EX-14 | J7B, P8 | EX-a; EX-b; crop CR-b; #782 | no | 0 | planned | - | - |
| EX-f | XMP sidecar on export | EX-15..EX-17 | J7S | EX-a; EX-b; EX-c; EX-d; EX-e | no | 0 | planned | - | - | first

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
| EX-a | contract: export plan, fake services, slots | EX-1..EX-3 | MX1 | nothing | no | 0 | planned | - | - |
| EX-b | File > Export sheet, real JPEG | EX-4..EX-6 | J7 | EX-a | yes | 0 | planned | - | - |
| EX-c | PNG/TIFF/HEIC formats | EX-7..EX-8 | J7F | EX-a; EX-b | yes | 0 | planned | - | - |
| EX-d | name templates, presets | EX-9..EX-11 | J7N | EX-a; EX-b | yes | 0 | planned | - | - |
| EX-e | progress, cancel, failures, cropped export | EX-12..EX-14 | J7B, P8 | EX-a; EX-b; crop CR-b; #782 | no | 0 | planned | - | - |
| EX-f | XMP sidecar on export | EX-15..EX-17 | J7S | EX-a; EX-b; EX-c; EX-d; EX-e | no | 0 | planned | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
| - | - | - | not yet planned: Stage 2 needs the packet's Build waves checked against the code | - | - | - | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
| - | - | - | - | - | - |

## Decisions
- Base is origin/dev, per CLAUDE.md ("never branch from or target main") and the playbook's stage 0. The brief says integrate on main (SHA 37d99630). Open for the supervisor.
- Stage 0 created this branch from origin/dev because lead/export did not exist on the remote.
- Cloud session: GitHub MCP tools disconnected mid-run, so PRs, labels and issue comments cannot be posted from here; git push still works.

## Open
- Supervisor: confirm base (dev or main) for PRs and the lane.
- Supervisor: GitHub tools disconnected; PRs and Belt-Slice-* comments need a session with GitHub access.
- Dependency status (wave.json): 
