// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NamazVakti",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NamazVakti",
            path: "Sources/NamazVakti"
        )
    ]
)
