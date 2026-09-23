// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RailCore",
    platforms: [.iOS(.v26), .macOS(.v14)],
    products: [.library(name: "RailCore", targets: ["RailCore"])],
    dependencies: [.package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20")],
    targets: [
        .target(name: "RailCore", dependencies: ["ZIPFoundation"]),
        .testTarget(name: "RailCoreTests", dependencies: ["RailCore", "ZIPFoundation"])
    ]
)
