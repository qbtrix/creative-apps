#!/usr/bin/env bash
# check.sh: proves the Folio blueprint's contracts compile in a Linux-safe
# Model target (Foundation only, Swift 6 language mode) and that the fakes pass
# the proof tests. Builds a throwaway package in a temp folder with every
# Swift file in this folder as the FolioModel target. No creative-core needed.
#   docs/blueprints/pdf/contracts/check.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/Sources/FolioModel" "$work/Tests/FolioContractTests"
cp -R "$here/Contracts" "$here/Fakes" "$here/FolioServices.swift" "$work/Sources/FolioModel/"
cp "$here"/Tests/*.swift "$work/Tests/FolioContractTests/"
cat >"$work/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "folio-contracts-check",
    platforms: [.macOS("26.0")],
    targets: [
        .target(name: "FolioModel"),
        .testTarget(name: "FolioContractTests", dependencies: ["FolioModel"]),
    ]
)
SWIFT
cd "$work"
if swift build --build-tests 2>&1 | grep -E 'error|warning: '; then
  echo "CONTRACTS: FAIL (compiler output above)"; exit 1
fi
swift test 2>&1 | tail -3
swift test >/dev/null 2>&1 && echo "CONTRACTS: PASS" || { echo "CONTRACTS: FAIL (tests)"; exit 1; }
