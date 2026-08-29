#if DEBUG
    import KatabroCore
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

    #Preview("Screen URLs — Normal") { screenURLsPreview(.results(screenURLs(count: 3))) }
    #Preview("Screen URLs — Loading") { screenURLsPreview(.loading) }
    #Preview("Screen URLs — Empty") { screenURLsPreview(.empty) }
    #Preview("Screen URLs — Permission") { screenURLsPreview(.permissionRequired) }
    #Preview("Screen URLs — Error") { screenURLsPreview(.captureFailed) }
    #Preview("Screen URLs — Many") { screenURLsPreview(.results(screenURLs(count: 12))) }

    @MainActor
    private func screenURLsPreview(_ state: ScreenURLPickerStore.State) -> some View {
        ScreenURLPickerView(store: ScreenURLPickerStore(state: state), onSelect: { _ in }, onCancel: {})
            .padding()
    }

    private func screenURLs(count: Int) -> [DetectedURL] {
        (1 ... count).compactMap { index in
            try? DetectedURL(destination: IncomingURL("https://preview\(index).example/path"))
        }
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
        let clipboardURLShortcutSettings = GlobalShortcutSettings(
            configuration: .init(
                identifier: .openURLFromClipboard,
                enabledKey: AppDelegate.clipboardShortcutEnabledKey,
                shortcutKey: AppDelegate.clipboardShortcutKey,
                defaultShortcut: .openURLFromClipboardDefault,
                registrationAllowed: true
            ),
            defaults: dependencies.globalShortcutDefaults,
            registrar: dependencies.globalHotKeyRegistrar
        )

        return SettingsView(
            browserDiscovery: dependencies.browserDiscovery,
            browserProfileStore: dependencies.browserProfileStore,
            defaultBrowserClient: dependencies.defaultBrowserClient,
            loginItemClient: dependencies.loginItemClient,
            clipboardURLShortcutSettings: clipboardURLShortcutSettings,
            screenURLCaptureSettings: ScreenURLCaptureSettings(
                defaults: isolatedPreviewScreenURLDefaults(),
                registrar: dependencies.globalHotKeyRegistrar,
                screenCaptureClient: dependencies.screenCaptureClient,
                isCaptureAvailable: dependencies.visionURLRecognitionClient.isAvailable()
            ),
            screenCaptureClient: dependencies.screenCaptureClient,
            visionURLRecognitionClient: dependencies.visionURLRecognitionClient,
            preferencesStore: dependencies.preferencesStore,
            routingDecisionLogStore: dependencies.routingDecisionLogStore,
            navigationStore: dependencies.settingsNavigationStore,
            userScriptBridge: dependencies.userScriptBridge,
            allowsSystemProfileConfiguration: dependencies.allowsSystemProfileConfiguration,
            onPreviewPicker: pickerCoordinator.preview
        )
    }

    private func isolatedPreviewScreenURLDefaults() -> UserDefaults {
        let suite = "com.zbiljic.katabro.screen-url-preview"
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("Could not create isolated Screen URL preview defaults")
        }
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
#endif
