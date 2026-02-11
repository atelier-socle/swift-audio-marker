// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "AudioMarker",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .visionOS(.v1),
    .macCatalyst(.v17)
  ],
  products: [
    .library(
      name: "AudioMarker",
      targets: ["AudioMarker"]
    ),
    .executable(
      name: "audio-marker",
      targets: ["AudioMarkerCLI"]
    )
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-argument-parser.git",
      from: "1.5.0"
    )
  ],
  targets: [
    .target(
      name: "AudioMarker",
      path: "Sources/AudioMarker"
    ),
    .target(
      name: "AudioMarkerCommands",
      dependencies: [
        "AudioMarker",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      path: "Sources/CLI"
    ),
    .executableTarget(
      name: "AudioMarkerCLI",
      dependencies: [
        "AudioMarkerCommands"
      ],
      path: "Sources/CLIEntry"
    ),
    .testTarget(
      name: "AudioMarkerTests",
      dependencies: [
        "AudioMarker"
      ],
      path: "Tests/AudioMarkerTests"
    ),
    .testTarget(
      name: "AudioMarkerCLITests",
      dependencies: [
        "AudioMarkerCommands",
        "AudioMarker"
      ],
      path: "Tests/AudioMarkerCLITests"
    )
  ]
)
