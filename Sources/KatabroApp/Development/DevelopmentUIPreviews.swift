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

    #Preview("Settings — About") {
        settingsPreview(
            state: .normal,
            pane: .about
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
            onSelect: { _ in },
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

        return SettingsView(
            browserDiscovery: dependencies.browserDiscovery,
            defaultBrowserClient: dependencies.defaultBrowserClient,
            loginItemClient: dependencies.loginItemClient,
            preferencesStore: dependencies.preferencesStore,
            initialPane: pane
        )
    }
#endif
