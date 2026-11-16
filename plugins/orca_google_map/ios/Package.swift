// swift-tools-version: 5.9
//
// The Orca Gateway Google map plugin for iOS: one library, OrcaGoogleMap, on
// the SDK's OrcaGateway product. Its props, params and trigger names are
// generated from ../orca_plugin.yaml (Sources/OrcaGoogleMap/Generated).
//
// The SDK comes from one of two places, chosen here from where this manifest
// is (not from the working directory):
//   - inside the monorepo (plugins/orca_google_map/ios/), ../../../sdk-swift
//     by path, so the plugin builds and tests against the SDK beside it;
//   - split out to its mirror (orca-gateway/orca-google-map-swift), where
//     that directory does not exist, the SDK's mirror orca-gateway-swift from
//     0.1.0-alpha.2, the first sdk-swift release that can carry the plugin API
//     this package builds on (0.1.0-alpha.1 has no OrcaPlugin).
// Release order: sdk-swift first, then this package, whose split resolves the
// SDK from its mirror.
import Foundation
import PackageDescription

let sdkPath = "../../../sdk-swift"
let inMonorepo = FileManager.default.fileExists(
    atPath: URL(fileURLWithPath: Context.packageDirectory).appendingPathComponent(sdkPath).path)
let sdk: (dependency: Package.Dependency, identity: String) = inMonorepo
    ? (.package(path: sdkPath), "sdk-swift")
    : (.package(url: "https://github.com/orca-gateway/orca-gateway-swift", from: "0.1.0-alpha.2"),
       "orca-gateway-swift")

let package = Package(
    name: "OrcaGoogleMap",
    // The SDK's platforms.
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "OrcaGoogleMap", targets: ["OrcaGoogleMap"]),
    ],
    dependencies: [sdk.dependency],
    targets: [
        .target(
            name: "OrcaGoogleMap",
            dependencies: [.product(name: "OrcaGateway", package: sdk.identity)]),
        .testTarget(
            name: "OrcaGoogleMapTests",
            dependencies: ["OrcaGoogleMap", .product(name: "OrcaGateway", package: sdk.identity)]),
    ]
)
