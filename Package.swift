// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HDF5Kit",
    products: [
        .library(
            name: "HDF5Kit",
            targets: ["HDF5Kit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/hacknus/CHDF5.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "HDF5Kit",
            dependencies: ["CHDF5"], // <-- Link CHDF5 explicitly
            path: "Source"
        ),
        .testTarget(
            name: "HDF5KitTests",
            dependencies: ["HDF5Kit"]
        ),
    ],
    swiftLanguageVersions: [.v4, .v5]
)
