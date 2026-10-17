# metadata-more lead record

Issue: #1555 · Packet: docs/blueprints/library/features/metadata-more.md
Run: act-1a147b718b0-qox5 · Session: resumed after worker restart · Started: 2026-10-17T03:07Z
Stage: 2 plan
Base: 82ac50553324ea359ca4b75c5d495fc812445cde (origin/dev)
Next: supervisor answers base (dev vs main); then plan waves against the current origin/dev and build the contract slice
| MD-b | Info tab camera details | MD-5..MD-8 | MD-J1 | MD-a; status-and-layout MD-8 | yes | 0 | planned | - | - |
| MD-c | keyword/title/caption edits with undo | MD-9..MD-13 | MD-J2 | MD-a; cull; persist; MD-b; filters; crop+export (MD-13) | yes | 0 | planned | - | - |
| MD-d | XMP sidecar writes | MD-14..MD-18 | MD-J3 | MD-a; MD-c; cull; filters | yes | 0 | planned | - | - |
| MD-e | search by keyword/camera | MD-19..MD-22 | MD-J4 | MD-a; filters; MD-d | yes | 0 | planned | - | - | first

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
| MD-a | contract: keywords, title, caption, camera fields, sidecar fake | MD-1..MD-4 | MD-MJ1 | cull MD-4 (built) | no | 0 | planned | - | - |
| MD-b | Info tab camera details | MD-5..MD-8 | MD-J1 | MD-a; status-and-layout MD-8 | yes | 0 | planned | - | - |
| MD-c | keyword/title/caption edits with undo | MD-9..MD-13 | MD-J2 | MD-a; cull; persist; MD-b; filters; crop+export (MD-13) | yes | 0 | planned | - | - |
| MD-d | XMP sidecar writes | MD-14..MD-18 | MD-J3 | MD-a; MD-c; cull; filters | yes | 0 | planned | - | - |
| MD-e | search by keyword/camera | MD-19..MD-22 | MD-J4 | MD-a; filters; MD-d | yes | 0 | planned | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
| - | - | - | not yet planned: Stage 2 needs the packet's Build waves checked against the code | - | - | - | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
| - | - | - | - | - | - |

## Decisions
- Base is origin/dev, per CLAUDE.md ("never branch from or target main") and the playbook's stage 0. The brief says integrate on main (SHA 37d99630). Open for the supervisor.
- Stage 0 created this branch from origin/dev because lead/metadata-more did not exist on the remote.
- Cloud session: GitHub MCP tools disconnected mid-run, so PRs, labels and issue comments cannot be posted from here; git push still works.

## Open
- Supervisor: confirm base (dev or main) for PRs and the lane.
- Supervisor: GitHub tools disconnected; PRs and Belt-Slice-* comments need a session with GitHub access.
- Dependency status (wave.json): 
