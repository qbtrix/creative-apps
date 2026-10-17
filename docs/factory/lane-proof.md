# Fast lane integration proofs

Throwaway PRs that showed the lane's rung 2a behaviour in production on
2026-10-16: a docs PR opened from a base 15 commits behind dev merged as it
was (no agent rebase), and `merge-driver-proof.json` next to this file was
built by two PRs that GitHub called conflicting; the lane merged dev into
the second one with the JSON merge driver, ran its Linux check and merged it.
