// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Notchify",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Notchify", targets: ["Notchify"])],
    targets: [
        .executableTarget(
            name: "Notchify",
            path: "Notchify",
            exclude: ["Info.plist", "Notchify.entitlements", "Assets"],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        )
    ]
)
