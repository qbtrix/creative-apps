#!/usr/bin/env bash
# check.sh: compiles Prism's contracts (Values, Rules, Contracts, Fakes,
# Services) in Swift 6 language mode with warnings as errors, Foundation only
# (no creative-core, no app target), and runs main.swift's proof checks.
# Prints "contracts: PASS". Needs only `swiftc` (Linux or macOS).
set -euo pipefail
cd "$(dirname "$0")"
out="${TMPDIR:-/tmp}/prism-contracts-check"
swiftc -swift-version 6 -warnings-as-errors Values.swift State.swift Rules.swift Contracts.swift Fakes.swift Services.swift main.swift -o "$out"
"$out" | tee /dev/stderr | grep -q "contracts: PASS"
