#if DEBUG
    import Foundation
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

        @MainActor
        @Test("file picker fixture is deterministic and omits the Remember footer")
        func filePickerFixture() {
            let fileStore = DevelopmentUIFixtures.pickerStore(for: .fileURL)
            let webStore = DevelopmentUIFixtures.pickerStore(for: .normal)

            #expect(fileStore.destination.url.absoluteString == "file:///fixture/index.html")
            #expect(!fileStore.canRememberSelection)
            #expect(
                Double(DevelopmentUIFixtures.pickerHeight(for: .normal)).bitPattern
                    == Double(
                        DevelopmentUIFixtures.pickerHeight(for: .fileURL)
                            + BrowserPickerLayout.sectionSpacing
                            + BrowserPickerLayout.rememberFooterHeight
                    ).bitPattern
            )
            #expect(fileStore.targets.count == webStore.targets.count)
        }

        @MainActor
        @Test("picker fixtures use compact production layout and a reserved long destination")
        func pickerFixturesUseProductionLayout() {
            let normal = DevelopmentUIFixtures.pickerStore(for: .normal)
            let many = DevelopmentUIFixtures.pickerStore(for: .manyBrowsers)
            #expect(DevelopmentUIFixtures.pickerHeight(for: .normal) == 257)
            #expect(DevelopmentUIFixtures.pickerHeight(for: .manyBrowsers) == 301)
            #expect(DevelopmentUIFixtures.pickerHeight(for: .normal) <= 280)
            #expect(DevelopmentUIFixtures.pickerHeight(for: .manyBrowsers) <= 320)
            #expect(normal.destination.url.absoluteString == "https://example.com")
            #expect(many.destination.url.absoluteString.contains("documentation.preview.long-subdomain.example.com"))
        }

        @Test("settings fixtures use an in-memory Folder transport and chooser")
        @MainActor
        func folderFixturesAreDeterministic() async throws {
            let normal = DevelopmentUIFixtures.dependencies(for: .normal)
            #expect(normal.preferencesStore.syncMethod == .folder)
            #expect(normal.preferencesStore.folderSyncStatus == .active(displayName: "Shared Katabro"))
            #expect(normal.configurationFolderClient.chooseDirectory()?.lastPathComponent == "Shared Katabro")
            let normalClient = normal.configurationFolderClient.makeClient(
                for: URL(fileURLWithPath: "/fixture/Shared Katabro", isDirectory: true)
            )
            #expect(try normalClient.bookmarkDataForDirectory() == nil)
            let normalStarted = normalClient.start(onEvent: { _ in }, refreshImmediately: false)
            #expect(normalStarted)
            normalClient.stop()

            let errors = DevelopmentUIFixtures.dependencies(for: .serviceErrors)
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: .seconds(2))
            while errors.preferencesStore.folderSyncStatus != .unavailable, clock.now < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(errors.preferencesStore.syncMethod == .folder)
            #expect(errors.preferencesStore.folderSyncStatus == .unavailable)
            #expect(errors.configurationFolderClient.chooseDirectory()?.lastPathComponent == "Shared Katabro")
            let errorClient = errors.configurationFolderClient.makeClient(
                for: URL(fileURLWithPath: "/fixture/Shared Katabro", isDirectory: true)
            )
            #expect(try errorClient.bookmarkDataForDirectory() == nil)
            let errorStarted = errorClient.start(onEvent: { _ in }, refreshImmediately: false)
            #expect(errorStarted)
            errorClient.stop()
            #expect(
                GeneralSettingsView.folderUnavailableMessage
                    == "Folder access is unavailable. Choose the folder again to recover."
            )
        }
    }
#endif
