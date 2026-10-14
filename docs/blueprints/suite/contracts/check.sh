#!/usr/bin/env bash
# check.sh: compiles the suite contracts (Values, Contracts, Fakes, Services, Packaging, HomeModel)
# in Swift 6 language mode with the Linux toolchain and runs main.swift's
# smoke checks. Prints "contracts: PASS". Needs only `swiftc` (scripts/cloud-setup.sh).
set -euo pipefail
cd "$(dirname "$0")"
out="${TMPDIR:-/tmp}/suite-contracts-check"
swiftc -swift-version 6 -warnings-as-errors Values.swift Contracts.swift Fakes.swift Services.swift Packaging.swift HomeModel.swift main.swift -o "$out"
"$out" | tee /dev/stderr | grep -q "contracts: PASS"
