#if DEBUG
    @testable import Katabro
    import Testing

    struct DevelopmentUIConfigurationTests {
        @Test(
            "parses every review surface",
            arguments: DevelopmentUISurface.allCases
        )
        func parsesSurface(
            surface: DevelopmentUISurface
        ) {
            let configuration = DevelopmentUIConfiguration.current(
                arguments: [
                    "Katabro",
                    DevelopmentUIConfiguration.surfaceArgument,
                    surface.rawValue,
                ]
            )

            #expect(
                configuration == DevelopmentUIConfiguration(
                    surface: surface,
                    state: .normal
                )
            )
        }

        @Test(
            "parses every fixture state",
            arguments: DevelopmentUIState.allCases
        )
        func parsesState(
            state: DevelopmentUIState
        ) {
            let configuration = DevelopmentUIConfiguration.current(
                arguments: [
                    "Katabro",
                    DevelopmentUIConfiguration.surfaceArgument,
                    DevelopmentUISurface.settings.rawValue,
                    DevelopmentUIConfiguration.stateArgument,
                    state.rawValue,
                ]
            )

            #expect(
                configuration == DevelopmentUIConfiguration(
                    surface: .settings,
                    state: state
                )
            )
        }

        @Test("requires a valid review surface")
        func requiresValidSurface() {
            #expect(
                DevelopmentUIConfiguration.current(
                    arguments: ["Katabro"]
                ) == nil
            )
            #expect(
                DevelopmentUIConfiguration.current(
                    arguments: [
                        "Katabro",
                        DevelopmentUIConfiguration.surfaceArgument,
                        "unknown",
                    ]
                ) == nil
            )
        }

        @Test("falls back to the normal fixture for an invalid state")
        func fallsBackForInvalidState() {
            let configuration = DevelopmentUIConfiguration.current(
                arguments: [
                    "Katabro",
                    DevelopmentUIConfiguration.surfaceArgument,
                    DevelopmentUISurface.settings.rawValue,
                    DevelopmentUIConfiguration.stateArgument,
                    "unknown",
                ]
            )

            #expect(configuration?.state == .normal)
        }

        @Test(
            "parses every review appearance",
            arguments: DevelopmentUIAppearance.allCases
        )
        func parsesAppearance(
            appearance: DevelopmentUIAppearance
        ) {
            let configuration = DevelopmentUIConfiguration.current(
                arguments: [
                    "Katabro",
                    DevelopmentUIConfiguration.surfaceArgument,
                    DevelopmentUISurface.settings.rawValue,
                    DevelopmentUIConfiguration.appearanceArgument,
                    appearance.rawValue,
                ]
            )

            #expect(configuration?.appearance == appearance)
        }

        @Test("parses persistent review preference arguments")
        func parsesReviewPreferences() {
            let configuration = DevelopmentUIConfiguration.current(
                arguments: [
                    "Katabro",
                    DevelopmentUIConfiguration.surfaceArgument,
                    DevelopmentUISurface.settings.rawValue,
                    DevelopmentUIConfiguration.preferencesSuiteArgument,
                    "shortcut-test",
                    DevelopmentUIConfiguration.resetPreferencesArgument,
                ]
            )

            #expect(configuration?.preferencesSuite == "shortcut-test")
            #expect(configuration?.resetsPreferences == true)
        }
    }
#endif
