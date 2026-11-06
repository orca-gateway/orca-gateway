// swift-tools-version: 5.9
//
// Orca Gateway iOS SDK (experimental). Two targets:
//   OrcaGatewayCore  pure Swift (Foundation only): wire models, ValueResolver,
//                    ElmStore, effects as data, generated capability vector.
//                    Builds and tests on Linux.
//   OrcaGateway      the SwiftUI layer (renderer, views, adapters). Compiles to
//                    an empty module where SwiftUI is unavailable.
//
// The tests read the conformance fixtures from ../schema at run time, so they
// only run inside the monorepo; the read-only mirror ships no tests.
import PackageDescription

let package = Package(
    name: "OrcaGateway",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "OrcaGateway", targets: ["OrcaGateway"]),
        .library(name: "OrcaGatewayCore", targets: ["OrcaGatewayCore"]),
    ],
    targets: [
        .target(name: "OrcaGatewayCore"),
        .target(name: "OrcaGateway", dependencies: ["OrcaGatewayCore"]),
        .testTarget(name: "OrcaGatewayCoreTests", dependencies: ["OrcaGatewayCore"]),
    ]
)
