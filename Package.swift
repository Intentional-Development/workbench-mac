// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WorkbenchMac",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "WorkbenchMac",
            dependencies: [],
            path: "Sources",
            linkerSettings: [
                .unsafeFlags([
                    "-L", "../idl-rs/target/release",
                    "-lidl_ffi"
                ])
            ]
        ),
        .testTarget(
            name: "WorkbenchMacTests",
            dependencies: ["WorkbenchMac"]
        ),
    ]
)
