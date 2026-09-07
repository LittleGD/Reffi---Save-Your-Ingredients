// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "PhosphorSwift", platforms: [.iOS(.v13)],
    products: [.library(name: "PhosphorSwift", targets: ["PhosphorSwift"])],
    targets: [.target(name: "PhosphorSwift", resources: [.process("Resources")])])
