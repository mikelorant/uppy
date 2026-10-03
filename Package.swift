// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Uppy",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(
      name: "Uppy",
      targets: ["Uppy"]
    )
  ],
  targets: [
    .executableTarget(
      name: "Uppy",
      dependencies: ["UppyCore", "UppyUI"],
      path: "Sources/Uppy"
    ),
    .target(name: "UppyCore"),
    .target(name: "UppyUI", dependencies: ["UppyCore"]),
    .executableTarget(
      name: "UppyUIChecks", dependencies: ["UppyCore", "UppyUI"], path: "Tests/UppyUIChecks"),
    .testTarget(name: "UppyTests", dependencies: ["UppyCore"]),
    .executableTarget(name: "UppyChecks", dependencies: ["UppyCore"], path: "Tests/UppyChecks"),
  ]
)
