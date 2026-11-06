// swift-tools-version: 5.9
//
// Orca Gateway iOS SDK (alpha). Two targets:
//   OrcaGatewayCore  pure Swift (Foundation only): wire models, ValueResolver,
//                    ElmStore, effects as data, generated capability vector.
//                    Builds and tests on Linux.
//   OrcaGateway      the SwiftUI layer (renderer, views, adapters). Compiles to
//                    an empty module where SwiftUI is unavailable.
//
// The tests read the conformance fixtures from ../schema, the recorded pages
// from Tests/Pages and the goldens from Tests/Goldens at run time, so they
// only run inside the monorepo. The read-only mirror (orca-gateway-swift)
// carries them as the subtree split leaves them; SwiftPM never builds a
// dependency's test targets.
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
        // SwiftUI tests: the page model everywhere SwiftUI exists, the golden
        // snapshot on an iOS simulator only. Empty on Linux.
        .testTarget(name: "OrcaGatewayTests", dependencies: ["OrcaGateway"]),
    ]
)
