import ProjectDescription

let sharedSettings: Settings = .settings(
    base: [
        "CLANG_ENABLE_MODULES": "YES",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "SWIFT_STRICT_CONCURRENCY": "complete",
        "SWIFT_VERSION": "6.3",
    ]
)

let appSettings: Settings = .settings(
    base: [
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
    ]
)

let iCloudAppSettings: Settings = .settings(
    base: [
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "CODE_SIGN_IDENTITY": "Apple Development",
        "CODE_SIGN_STYLE": "Automatic",
        "PRODUCT_MODULE_NAME": "KatabroICloud",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) KATABRO_ICLOUD",
        "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
    ]
)

let cliSettings: Settings = .settings(
    base: [
        "PRODUCT_MODULE_NAME": "KatabroCLI",
        "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
    ]
)

let project = Project(
    name: "Katabro",
    organizationName: "zbiljic",
    options: .options(
        automaticSchemesOptions: .disabled,
        developmentRegion: "en",
        textSettings: .textSettings(
            usesTabs: false,
            indentWidth: 4,
            tabWidth: 4,
            wrapsLines: true
        )
    ),
    settings: sharedSettings,
    targets: [
        .target(
            name: "KatabroCore",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.zbiljic.katabrocore",
            deploymentTargets: .macOS("14.0"),
            sources: ["Packages/KatabroCore/Sources/**"]
        ),
        .target(
            name: "KatabroCLI",
            destinations: .macOS,
            product: .commandLineTool,
            productName: "katabro",
            bundleId: "com.zbiljic.katabro-cli",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/KatabroCLI/**"],
            dependencies: [
                .target(name: "KatabroCore"),
            ],
            settings: cliSettings
        ),
        .target(
            name: "Katabro",
            destinations: .macOS,
            product: .app,
            bundleId: "com.zbiljic.katabro",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .file(path: "Resources/Info.plist"),
            sources: ["Sources/KatabroApp/**"],
            resources: [
                "Resources/Assets.xcassets",
                "Resources/Scripts/**",
            ],
            copyFiles: [
                .wrapper(
                    name: "Embed command-line helper",
                    subpath: "Contents/Helpers",
                    files: [
                        .buildProduct(
                            name: "KatabroCLI",
                            codeSignOnCopy: true
                        ),
                    ]
                ),
            ],
            entitlements: .file(path: "Resources/Katabro.entitlements"),
            dependencies: [
                .target(name: "KatabroCore"),
                .target(
                    name: "KatabroCLI",
                    status: .none
                ),
            ],
            settings: appSettings
        ),
        .target(
            name: "Katabro iCloud",
            destinations: .macOS,
            product: .app,
            productName: "Katabro",
            bundleId: "com.zbiljic.katabro",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .file(path: "Resources/Info.plist"),
            sources: ["Sources/KatabroApp/**"],
            resources: [
                "Resources/Assets.xcassets",
                "Resources/Scripts/**",
            ],
            copyFiles: [
                .wrapper(
                    name: "Embed command-line helper",
                    subpath: "Contents/Helpers",
                    files: [
                        .buildProduct(
                            name: "KatabroCLI",
                            codeSignOnCopy: true
                        ),
                    ]
                ),
            ],
            entitlements: .file(path: "Resources/Katabro.iCloud.entitlements"),
            dependencies: [
                .target(name: "KatabroCore"),
                .target(
                    name: "KatabroCLI",
                    status: .none
                ),
            ],
            settings: iCloudAppSettings
        ),
        .target(
            name: "KatabroTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.zbiljic.katabrotests",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .default,
            sources: ["Tests/KatabroAppTests/**"],
            dependencies: [
                .target(name: "Katabro"),
            ],
            settings: appSettings
        ),
        .target(
            name: "KatabroUITests",
            destinations: .macOS,
            product: .uiTests,
            bundleId: "com.zbiljic.katabrouitests",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .default,
            sources: ["Tests/KatabroUITests/**"],
            dependencies: [
                .target(name: "Katabro"),
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "Katabro",
            shared: true,
            buildAction: .buildAction(
                targets: ["Katabro"]
            ),
            testAction: .targets(
                [
                    .testableTarget(
                        target: "KatabroTests",
                        parallelization: .swiftTestingOnly
                    ),
                    .testableTarget(
                        target: "KatabroUITests"
                    ),
                ],
                options: .options(
                    coverage: true,
                    codeCoverageTargets: ["Katabro", "KatabroCore"]
                )
            ),
            runAction: .runAction(
                executable: "Katabro"
            )
        ),
        .scheme(
            name: "Katabro iCloud",
            shared: true,
            buildAction: .buildAction(
                targets: ["Katabro iCloud"]
            ),
            runAction: .runAction(
                executable: "Katabro iCloud"
            )
        ),
    ]
)
