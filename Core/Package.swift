// swift-tools-version:5.9
import PackageDescription

// The parts of AMS Mail Menu that need no screen: the scripts sent to Apple Mail, reading Mail's
// answers, grouping by sender, links, settings names. They can be tested in seconds.
let package = Package(
    name: "MailMenuCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "MailMenuCore", targets: ["MailMenuCore"])],
    targets: [
        .target(name: "MailMenuCore"),
        .testTarget(name: "MailMenuCoreTests", dependencies: ["MailMenuCore"]),
    ]
)
