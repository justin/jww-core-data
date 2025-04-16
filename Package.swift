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
        .package(url: "https://github.com/justin/jww-standard-lib.git", from: "1.0.3")
    ],
    targets: [
        .target(name: "JWWCoreData",
                dependencies: [
                    .product(name: "JWWCore", package: "jww-standard-lib")
                ]),
        .testTarget(name: "JWWCoreDataTests",
                    dependencies: [
                        .product(name: "JWWCore", package: "jww-standard-lib")
                    ],
                    resources: [
                        .process("Resources")
                    ]
        )
    ]
)
