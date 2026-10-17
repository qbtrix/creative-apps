# crop lead record

Issue: #1553 · Packet: docs/blueprints/library/features/crop.md
Run: act-1a147b718b0-qox5 · Session: resumed after worker restart · Started: 2026-10-17T03:07Z
Stage: 2 plan
Base: 82ac50553324ea359ca4b75c5d495fc812445cde (origin/dev)
Next: supervisor answers base (dev vs main); then plan waves against the current origin/dev and build the contract slice
| CR-b | real pixels crop and straighten | CR-3, CR-4 | MJ6L | CR-a | no | 0 | planned | - | - |
| CR-c | Photo > Crop UI | CR-5, CR-6 | J6 | CR-a; spine follow-up; develop inspector follow-up | yes | 0 | planned | - | - |
| CR-d | integrate on live services | CR-7, CR-8 | J6, P5 | CR-b; CR-c; #782 | no | 0 | planned | - | - |
| CR-e | Auto levels (core issue) | CR-9, CR-10 | MJ6A | CR-a; CR-b; creative-core issue and bump | no | 0 | planned | - | - | first

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
| CR-a | contract: crop catalog methods, CropLeveling slot, FakeCrop | CR-1, CR-2 | MJ6 | develop (the feature, planned) | no | 0 | planned | - | - |
| CR-b | real pixels crop and straighten | CR-3, CR-4 | MJ6L | CR-a | no | 0 | planned | - | - |
| CR-c | Photo > Crop UI | CR-5, CR-6 | J6 | CR-a; spine follow-up; develop inspector follow-up | yes | 0 | planned | - | - |
| CR-d | integrate on live services | CR-7, CR-8 | J6, P5 | CR-b; CR-c; #782 | no | 0 | planned | - | - |
| CR-e | Auto levels (core issue) | CR-9, CR-10 | MJ6A | CR-a; CR-b; creative-core issue and bump | no | 0 | planned | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
| - | - | - | not yet planned: Stage 2 needs the packet's Build waves checked against the code | - | - | - | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
| - | - | - | - | - | - |

## Decisions
- Base is origin/dev, per CLAUDE.md ("never branch from or target main") and the playbook's stage 0. The brief says integrate on main (SHA 37d99630). Open for the supervisor.
- Stage 0 created this branch from origin/dev because lead/crop did not exist on the remote.
- Cloud session: GitHub MCP tools disconnected mid-run, so PRs, labels and issue comments cannot be posted from here; git push still works.

## Open
- Supervisor: confirm base (dev or main) for PRs and the lane.
- Supervisor: GitHub tools disconnected; PRs and Belt-Slice-* comments need a session with GitHub access.
- Dependency status (wave.json): 
