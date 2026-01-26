// swift-tools-version: 6.2
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "SkillsBar",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/steipete/Commander", from: "0.2.1"),
        .package(url: "https://github.com/apple/swift-log", from: "1.9.1"),
        .package(url: "https://github.com/apple/swift-syntax", from: "600.0.1"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"),
    ],
    targets: {
        var targets: [Target] = [
            .target(
                name: "SkillsBarCore",
                dependencies: [
                    "SkillsBarMacroSupport",
                    .product(name: "Logging", package: "swift-log"),
                ],
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .macro(
                name: "SkillsBarMacros",
                dependencies: [
                    .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                    .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                    .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                ]),
            .target(
                name: "SkillsBarMacroSupport",
                dependencies: [
                    "SkillsBarMacros",
                ]),
            .executableTarget(
                name: "SkillsBarCLI",
                dependencies: [
                    "SkillsBarCore",
                    .product(name: "Commander", package: "Commander"),
                ],
                path: "Sources/SkillsBarCLI",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .testTarget(
                name: "SkillsBarLinuxTests",
                dependencies: ["SkillsBarCore", "SkillsBarCLI"],
                path: "TestsLinux",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                    .enableExperimentalFeature("SwiftTesting"),
                ]),
        ]

        #if os(macOS)
        targets.append(contentsOf: [
            .executableTarget(
                name: "SkillsBar",
                dependencies: [
                    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                    "SkillsBarMacroSupport",
                    "SkillsBarCore",
                ],
                path: "Sources/SkillsBar",
                resources: [
                    .process("Resources"),
                ],
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .executableTarget(
                name: "SkillsBarWidget",
                dependencies: ["SkillsBarCore"],
                path: "Sources/SkillsBarWidget",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
        ])

        targets.append(.testTarget(
            name: "SkillsBarTests",
            dependencies: ["SkillsBar", "SkillsBarCore", "SkillsBarCLI"],
            path: "Tests",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ]))
        #endif

        return targets
    }())
