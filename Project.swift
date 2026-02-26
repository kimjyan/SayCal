import ProjectDescription

let project = Project(
    name: "SayCal",
    options: .options(
        defaultKnownRegions: ["en", "ko"],
        developmentRegion: "en"
    ),
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "HCL3R5DRWV",
            "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
            "SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY": "YES",
        ]
    ),
    targets: [
        .target(
            name: "SayCal",
            destinations: .iOS,
            product: .app,
            bundleId: "com.-jay.cal.SayCal",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": .dictionary([:]),
            ]),
            sources: ["SayCal/**/*.swift"],
            resources: ["SayCal/**/*.xcassets"],
            dependencies: [
                .external(name: "ComposableArchitecture"),
            ]
        ),
        .target(
            name: "SayCalTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.-jay.cal.SayCalTests",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .default,
            sources: ["SayCalTests/**/*.swift"],
            dependencies: [
                .target(name: "SayCal"),
            ]
        ),
        .target(
            name: "SayCalUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "com.-jay.cal.SayCalUITests",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .default,
            sources: ["SayCalUITests/**/*.swift"],
            dependencies: [
                .target(name: "SayCal"),
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "SayCal",
            buildAction: .buildAction(targets: ["SayCal"]),
            testAction: .targets(
                ["SayCalTests", "SayCalUITests"],
                configuration: .debug
            ),
            runAction: .runAction(configuration: .debug),
            archiveAction: .archiveAction(configuration: .release)
        ),
    ]
)
