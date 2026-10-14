#!/usr/bin/env bash
# check.sh: proves the Halo blueprint's contracts compile and their fakes pass
# on Linux (or macOS), against today's HaloModel and creative-core main.
# It builds a throwaway package in a temp folder: HaloModel's current sources,
# with HaloLayer.swift replaced by W0/HaloLayer.swift (the W0 fields) and
# HaloComposition made Codable, plus every file in this folder.
#   docs/blueprints/halo/contracts/check.sh            # fetches creative-core main
#   CORE_PATH=../creative-core docs/blueprints/halo/contracts/check.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/Sources/HaloModel" "$work/Tests/HaloContractTests"
cp "$repo"/Sources/HaloModel/*.swift "$work/Sources/HaloModel/"
cp "$here/W0/HaloLayer.swift" "$work/Sources/HaloModel/HaloLayer.swift"
sed -i.bak 's/public struct HaloComposition: Identifiable, Sendable, Hashable {/public struct HaloComposition: Identifiable, Codable, Sendable, Hashable {/' \
  "$work/Sources/HaloModel/HaloProject.swift" && rm "$work/Sources/HaloModel/HaloProject.swift.bak"
cp -R "$here/Contracts" "$here/Fakes" "$work/Sources/HaloModel/"
cp "$here"/HaloServices.swift "$here"/LiveStubs.swift "$here"/HaloLayerDefaults.swift "$work/Sources/HaloModel/"
cp "$here"/Tests/*.swift "$work/Tests/HaloContractTests/"
if [ -n "${CORE_PATH:-}" ]; then
  core=".package(path: \"$(cd "$CORE_PATH" && pwd)\")"; pkg=$(basename "$(cd "$CORE_PATH" && pwd)")
else
  core='.package(url: "https://github.com/qbtrix/creative-core", branch: "main")'; pkg=creative-core
fi
cat >"$work/Package.swift" <<SWIFT
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "halo-contracts-check",
    platforms: [.macOS("26.0")], dependencies: [$core],
    targets: [
        .target(name: "HaloModel", dependencies: [
            .product(name: "FlareCore", package: "$pkg"), .product(name: "CoreRaster", package: "$pkg")]),
        .testTarget(name: "HaloContractTests", dependencies: ["HaloModel"]),
    ]
)
SWIFT
cd "$work"
swift build --build-tests 2>&1 | grep -E 'error|warning: ' && { echo "CONTRACTS: FAIL (compiler output above)"; exit 1; }
swift test 2>&1 | tail -3
swift test >/dev/null 2>&1 && echo "CONTRACTS: PASS" || { echo "CONTRACTS: FAIL (tests)"; exit 1; }
