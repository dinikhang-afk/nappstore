// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NappStore",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "NappStore",
            targets: ["NappStore"]
        ),
    ],
    targets: [
        .target(
            name: "NappStore",
            path: "Sources"
        )
    ]
)
