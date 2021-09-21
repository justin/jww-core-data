// swift-tools-version:5.5

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
        .library(name: "JWW Core Data", targets: ["JWWCoreData"])
    ],
    dependencies: [
        .package(name: "JWWCore", url: "git@github.com:justin/jww-standard-lib.git", from: "1.0.3")
    ],
    targets: [
        .target(name: "JWWCoreData",
                dependencies: [
                    "JWWCore"
                ]),
        .testTarget(name: "JWWCoreDataTests",
                    dependencies: ["JWWCoreData"],
                    resources: [
                        .process("Resources")
                    ]
        )
    ]
)
