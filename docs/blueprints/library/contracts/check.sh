#!/usr/bin/env bash
# check.sh: proves the Library blueprint's contracts (section 5) compile on
# Linux in Swift 6 mode against creative-core main, and that the fakes drive
# every contract. Copies this folder over today's Sources/LibraryModel in a
# scratch package (PhotoItem.swift here is the spine's version of the file)
# and runs the smoke tests plus every existing LibraryModel test. Usage: docs/blueprints/library/contracts/check.sh
# [scratch dir]. Needs swift and git. Not part of scripts/ci.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../../.." && pwd)"
work="${1:-$(mktemp -d)}"
[ -d "$work/core" ] || git clone -q --depth 1 https://github.com/qbtrix/creative-core "$work/core"
pkg="$work/contracts"
rm -rf "$pkg" && mkdir -p "$pkg/Sources" "$pkg/Tests/LibraryModelTests"
cp -r "$repo/Sources/LibraryModel" "$pkg/Sources/LibraryModel"
cp -r "$here/Contracts" "$here/Fakes" "$here/Live" "$here/LibraryServices.swift" "$here/PhotoItem.swift" "$here/SampleImage.swift" "$pkg/Sources/LibraryModel/"
cp "$repo"/Tests/LibraryModelTests/*.swift "$pkg/Tests/LibraryModelTests/"
cp "$here/ContractSmokeTests.swift" "$pkg/Tests/LibraryModelTests/"
cat >"$pkg/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "contracts",
    dependencies: [.package(path: "../core")],
    targets: [
        .target(name: "LibraryModel", dependencies: [.product(name: "CoreRaster", package: "core"), .product(name: "CoreColor", package: "core")]),
        .testTarget(name: "LibraryModelTests", dependencies: ["LibraryModel"]),
    ]
)
SWIFT
cd "$pkg" && swift test
