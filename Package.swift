// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LaudspeakerSWIFT",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "LaudspeakerSWIFT",
            targets: ["LaudspeakerSWIFT"]),

    ],
    dependencies: [
        .package(name: "SocketIO",url: "https://github.com/socketio/socket.io-client-swift", .upToNextMinor(from: "16.1.0")),
        .package(
            name: "Firebase",
          url: "https://github.com/firebase/firebase-ios-sdk.git",
          .upToNextMajor(from: "10.4.0")
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LaudspeakerSWIFT",
            dependencies: [.product(name: "SocketIO", package: "SocketIO" ),.product(name: "FirebaseMessaging", package: "Firebase" )]
        ),
        .testTarget(
            name: "LaudspeakerSWIFTTests",
            dependencies: ["LaudspeakerSWIFT"]),
    ]
)
