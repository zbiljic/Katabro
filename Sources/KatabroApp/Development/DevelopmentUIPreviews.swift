#if DEBUG
    import SwiftUI

    #Preview("Settings — General Normal") {
        settingsPreview(
            state: .normal,
            pane: .general
        )
    }

    #Preview("Settings — General Service Errors") {
        settingsPreview(
            state: .serviceErrors,
            pane: .general
        )
    }

    #Preview("Settings — Browsers Normal") {
        settingsPreview(
            state: .normal,
            pane: .browsers
        )
    }

    #Preview("Settings — Browsers No Browsers") {
        settingsPreview(
            state: .noBrowsers,
            pane: .browsers
        )
    }

    #Preview("Settings — Browsers Discovery Error") {
        settingsPreview(
            state: .browserDiscoveryError,
            pane: .browsers
        )
    }

    #Preview("Settings — Browsers Many Browsers") {
        settingsPreview(
            state: .manyBrowsers,
            pane: .browsers
        )
    }

    #Preview("Settings — Launcher Helper Setup") {
        settingsPreview(
            state: .scriptSetup,
            pane: .browsers
        )
    }

    #Preview("Settings — Launcher Helper Replacement") {
        settingsPreview(
            state: .scriptReplace,
            pane: .browsers
        )
    }

    #Preview("Settings — About") {
        settingsPreview(
            state: .normal,
            pane: .about
        )
    }

    #Preview("Settings — Rules") {
        settingsPreview(
            state: .normal,
            pane: .rules
        )
    }

    #Preview("Settings — Recent Routes") {
        settingsPreview(
            state: .recentRoutes,
            pane: .rules
        )
    }

    #Preview("Settings — Recent Routes Empty") {
        settingsPreview(
            state: .recentRoutesEmpty,
            pane: .rules
        )
    }

    #Preview("Onboarding") {
        let dependencies = DevelopmentUIFixtures.dependencies(
            for: .normal
        )

        OnboardingView(
            defaultBrowserClient: dependencies.defaultBrowserClient,
            preferencesStore: dependencies.preferencesStore
        ) {}
    }

    #Preview("Browser Picker") {
        BrowserPickerView(
            store: DevelopmentUIFixtures.pickerStore(
                for: .normal
            ),
            onSelect: { _, _ in },
            onCopyLink: {},
            onCancel: {}
        )
    }

    #Preview("Browser Picker — Many Browsers") {
        BrowserPickerView(
            store: DevelopmentUIFixtures.pickerStore(
                for: .manyBrowsers
            ),
            onSelect: { _, _ in },
            onCopyLink: {},
            onCancel: {}
        )
    }

    #Preview("Browser Picker — File URL") {
        BrowserPickerView(
            store: DevelopmentUIFixtures.pickerStore(
                for: .fileURL
            ),
            onSelect: { _, _ in },
            onCopyLink: {},
            onCancel: {}
        )
    }

    @MainActor
    private func settingsPreview(
        state: DevelopmentUIState,
        pane: SettingsPane
    ) -> some View {
        let dependencies = DevelopmentUIFixtures.dependencies(
            for: state
        )
        let pickerCoordinator = BrowserPickerCoordinator(
            dependencies: dependencies
        )
        dependencies.settingsNavigationStore.select(pane)

        return SettingsView(
            browserDiscovery: dependencies.browserDiscovery,
            browserProfileStore: dependencies.browserProfileStore,
            defaultBrowserClient: dependencies.defaultBrowserClient,
            loginItemClient: dependencies.loginItemClient,
            preferencesStore: dependencies.preferencesStore,
            routingDecisionLogStore: dependencies.routingDecisionLogStore,
            navigationStore: dependencies.settingsNavigationStore,
            userScriptBridge: dependencies.userScriptBridge,
            allowsSystemProfileConfiguration: dependencies.allowsSystemProfileConfiguration,
            onPreviewPicker: pickerCoordinator.preview
        )
    }
#endif
