// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "JWW Core Data",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
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
                        .target(name: "JWWCoreData"),
                        .product(name: "JWWCore", package: "jww-standard-lib")
                    ],
                    resources: [
                        .process("Resources")
                    ]
        )
    ]
)
