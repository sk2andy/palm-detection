// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PalmGuard",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PalmGuard", targets: ["PalmGuard"])],
    targets: [
        .target(name: "PalmGuardCore"),
        .target(
            name: "MultitouchBridge",
            linkerSettings: [
                .linkedFramework("CoreFoundation"), .linkedFramework("IOKit"),
            ]),
        .executableTarget(name: "PalmGuard", dependencies: ["PalmGuardCore", "MultitouchBridge"]),
        .testTarget(name: "PalmGuardCoreTests", dependencies: ["PalmGuardCore"]),
        .testTarget(name: "PalmGuardAppTests", dependencies: ["PalmGuard", "MultitouchBridge"]),
    ]
)
