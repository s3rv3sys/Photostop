// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PhotoStop",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PhotoStop",
            targets: ["PhotoStop"]),
    ],
    dependencies: [
        .package(url: "https://github.com/google/generative-ai-swift", from: "0.4.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")
    ],
    targets: [
        .target(
            name: "PhotoStop",
            dependencies: [
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift"),
                "Alamofire"
            ]),
        .testTarget(
            name: "PhotoStopTests",
            dependencies: ["PhotoStop"]),
    ]
)

