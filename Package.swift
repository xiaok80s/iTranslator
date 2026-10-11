// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "iTranslator",
    platforms: [.macOS("15.0")],
    targets: [
        .executableTarget(name: "iTranslator", path: "Sources/iTranslator")
    ]
)
