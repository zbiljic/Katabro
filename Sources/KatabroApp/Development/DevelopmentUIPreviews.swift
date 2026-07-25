#if DEBUG
    import SwiftUI

    #Preview("Settings — Normal") {
        let dependencies = DevelopmentUIFixtures.dependencies(
            for: .normal
        )

        SettingsView(
            browserDiscovery: dependencies.browserDiscovery,
            defaultBrowserClient: dependencies.defaultBrowserClient,
            loginItemClient: dependencies.loginItemClient,
            preferencesStore: dependencies.preferencesStore
        )
    }

    #Preview("Settings — No Browsers") {
        let dependencies = DevelopmentUIFixtures.dependencies(
            for: .noBrowsers
        )

        SettingsView(
            browserDiscovery: dependencies.browserDiscovery,
            defaultBrowserClient: dependencies.defaultBrowserClient,
            loginItemClient: dependencies.loginItemClient,
            preferencesStore: dependencies.preferencesStore
        )
    }

    #Preview("Settings — Service Errors") {
        let dependencies = DevelopmentUIFixtures.dependencies(
            for: .serviceErrors
        )

        SettingsView(
            browserDiscovery: dependencies.browserDiscovery,
            defaultBrowserClient: dependencies.defaultBrowserClient,
            loginItemClient: dependencies.loginItemClient,
            preferencesStore: dependencies.preferencesStore
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
#endif
