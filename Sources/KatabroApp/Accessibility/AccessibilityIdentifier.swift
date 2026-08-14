enum AccessibilityIdentifier {
    static let menuOpenTestPicker = "menu.open-test-picker"
    static let menuSetupGuide = "menu.setup-guide"
    static let menuSettings = "menu.settings"
    static let menuDefaultBrowserStatus = "menu.default-browser-status"
    static let menuQuit = "menu.quit"

    static let settingsGeneralPane = "settings.pane.general"
    static let settingsBrowsersPane = "settings.pane.browsers"
    static let settingsAboutPane = "settings.pane.about"
    static let settingsGeneralForm = "settings.general.form"
    static let settingsBrowsersForm = "settings.browsers.form"
    static let settingsAboutContent = "settings.about.content"
    static let settingsAboutVersion = "settings.about.version"
    static let settingsAboutRepositoryLink = "settings.about.link.repository"
    static let settingsAboutIssuesLink = "settings.about.link.issues"
    static let settingsAboutLicenseLink = "settings.about.link.license"
    static let settingsDefaultBrowserStatus = "settings.default-browser.status"
    static let settingsDefaultBrowserAction = "settings.default-browser.action"
    static let settingsDefaultBrowserError = "settings.default-browser.error"
    static let settingsLoginItemToggle = "settings.login-item.toggle"
    static let settingsLoginItemStatus = "settings.login-item.status"
    static let settingsLoginItemError = "settings.login-item.error"
    static let settingsICloudStatus = "settings.icloud.status"
    static let settingsBrowserList = "settings.browser-list"
    static let settingsBrowserRefresh = "settings.browser-refresh"
    static let settingsBrowserReset = "settings.browser-reset"
    static let settingsBrowserShowAll = "settings.browser-show-all"

    static let onboardingDefaultBrowserStatus = "onboarding.default-browser.status"
    static let onboardingDefaultBrowserAction = "onboarding.default-browser.action"
    static let onboardingDefaultBrowserError = "onboarding.default-browser.error"
    static let onboardingDone = "onboarding.done"

    static let pickerDestination = "picker.destination"
    static let pickerEmptyState = "picker.empty-state"
    static let pickerSelectionReceipt = "picker.selection-receipt"
    static let pickerCancellationReceipt = "picker.cancellation-receipt"

    static func browserOrderRow(
        bundleIdentifier: String
    ) -> String {
        "settings.browser-row.\(bundleIdentifier)"
    }

    static func browserOrderMoveUp(
        bundleIdentifier: String
    ) -> String {
        "settings.browser-row.\(bundleIdentifier).move-up"
    }

    static func browserOrderMoveDown(
        bundleIdentifier: String
    ) -> String {
        "settings.browser-row.\(bundleIdentifier).move-down"
    }

    static func browserVisibility(
        bundleIdentifier: String
    ) -> String {
        "settings.browser-row.\(bundleIdentifier).visibility"
    }

    static func browserPickerShortcut(
        bundleIdentifier: String
    ) -> String {
        "settings.browser-row.\(bundleIdentifier).shortcut"
    }

    static func browserPickerShortcutClear(
        bundleIdentifier: String
    ) -> String {
        "settings.browser-row.\(bundleIdentifier).shortcut-clear"
    }

    static func pickerBrowser(
        bundleIdentifier: String
    ) -> String {
        "picker.browser.\(bundleIdentifier)"
    }

    static func pickerTarget(
        identifier: String
    ) -> String {
        "picker.target.\(identifier)"
    }

    static func settingsProfileBrowser(
        bundleIdentifier: String
    ) -> String {
        "settings.profile-browser.\(bundleIdentifier)"
    }
}
