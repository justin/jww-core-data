// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "JWW Core Data",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        .library(name: "JWW Core Data", targets: ["JWWCoreData"]),
    ],
    targets: [
        .target( name: "JWWCoreData"),
        .testTarget(name: "JWWCoreDataTests",
                    dependencies: ["JWWCoreData"],
                    resources: [
                        .process("Resources")
                    ]
        )
    ]
)
