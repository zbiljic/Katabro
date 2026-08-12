enum AccessibilityIdentifier {
    static let menuOpenTestPicker = "menu.open-test-picker"
    static let menuSetupGuide = "menu.setup-guide"
    static let menuSettings = "menu.settings"
    static let menuDefaultBrowserStatus = "menu.default-browser-status"
    static let menuQuit = "menu.quit"

    static let settingsGeneralPane = "settings.pane.general"
    static let settingsBrowsersPane = "settings.pane.browsers"
    static let settingsGeneralForm = "settings.general.form"
    static let settingsBrowsersForm = "settings.browsers.form"
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

    static func pickerBrowser(
        bundleIdentifier: String
    ) -> String {
        "picker.browser.\(bundleIdentifier)"
    }
}
