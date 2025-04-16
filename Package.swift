// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "JWWData",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(name: "JWWData", targets: ["JWWCoreData", "JWWSwiftData"]),
        .library(name: "JWW Core Data", targets: ["JWWCoreData"]),
        .library(name: "JWW SwiftData", targets: ["JWWSwiftData"])
    ],
    dependencies: [
        .package(url: "https://github.com/justin/jww-standard-lib.git", from: "1.0.3")
    ],
    targets: [
        .target(name: "JWWSwiftData",
                dependencies: [
                    .target(name: "_JWWDataInternal"),
                    .product(name: "JWWCore", package: "jww-standard-lib")
                ]),
        .testTarget(name: "JWWSwiftDataTests",
                    dependencies: [
                        .target(name: "JWWSwiftData"),
                        .product(name: "JWWCore", package: "jww-standard-lib"),
                    ]
        ),

        .target(name: "JWWCoreData",
                dependencies: [
                    .target(name: "_JWWDataInternal"),
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
        ),

            .target(name: "_JWWDataInternal",
                    dependencies: [
                        .product(name: "JWWCore", package: "jww-standard-lib")
                    ])

    ]
)
