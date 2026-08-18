enum AccessibilityIdentifier {
    static let menuOpenTestPicker = "menu.open-test-picker"
    static let menuSetupGuide = "menu.setup-guide"
    static let menuSettings = "menu.settings"
    static let menuDefaultBrowserStatus = "menu.default-browser-status"
    static let menuQuit = "menu.quit"

    static let settingsGeneralPane = "settings.pane.general"
    static let settingsBrowsersPane = "settings.pane.browsers"
    static let settingsPickerPane = "settings.pane.picker"
    static let settingsRulesPane = "settings.pane.rules"
    static let settingsAboutPane = "settings.pane.about"
    static let settingsGeneralForm = "settings.general.form"
    static let settingsBrowsersForm = "settings.browsers.form"
    static let settingsPickerForm = "settings.picker.form"
    static let settingsPickerOrientation = "settings.picker.orientation"
    static let settingsPickerVerticalWidth = "settings.picker.vertical-width"
    static let settingsPickerVisibleChoices = "settings.picker.visible-choices"
    static let settingsPickerDestination = "settings.picker.destination"
    static let settingsPickerShortcutHints = "settings.picker.shortcut-hints"
    static let settingsPickerShortcutHintsHiddenNote = "settings.picker.shortcut-hints-hidden-note"
    static let settingsPickerHorizontalLabels = "settings.picker.horizontal-labels"
    static let settingsPickerShowRemember = "settings.picker.show-remember"
    static let settingsPickerPreview = "settings.picker.preview"
    static let settingsRulesForm = "settings.rules.form"
    static let settingsRulesEmpty = "settings.rules.empty"
    static let settingsRulesRemoveAll = "settings.rules.remove-all"
    static let settingsAboutContent = "settings.about.content"
    static let settingsAboutVersion = "settings.about.version"
    static let settingsAboutRepositoryLink = "settings.about.link.repository"
    static let settingsAboutIssuesLink = "settings.about.link.issues"
    static let settingsAboutLicenseLink = "settings.about.link.license"
    static let settingsDefaultBrowserStatus = "settings.default-browser.status"
    static let settingsDefaultBrowserAction = "settings.default-browser.action"
    static let settingsDefaultBrowserActive = "settings.default-browser.active"
    static let settingsDefaultBrowserError = "settings.default-browser.error"
    static let settingsLoginItemToggle = "settings.login-item.toggle"
    static let settingsLoginItemStatus = "settings.login-item.status"
    static let settingsLoginItemError = "settings.login-item.error"
    static let settingsICloudStatus = "settings.icloud.status"
    static let settingsSyncMethod = "settings.sync.method"
    // Keep the original identifier stable for UI clients while the section
    // itself is now transport-neutral.
    static let settingsSyncStatus = settingsICloudStatus
    static let settingsSyncFolderName = "settings.sync.folder-name"
    static let settingsSyncChooseFolder = "settings.sync.choose-folder"
    static let settingsSyncDisconnect = "settings.sync.disconnect"
    static let settingsSyncError = "settings.sync.error"
    static let settingsSyncDisclosureContinue = "settings.sync.disclosure.continue"
    static let settingsSyncDisclosureCancel = "settings.sync.disclosure.cancel"
    static let settingsSyncAdopt = "settings.sync.adoption.use-folder"
    static let settingsSyncReplace = "settings.sync.adoption.replace-file"
    static let settingsSyncAdoptionCancel = "settings.sync.adoption.cancel"
    static let settingsBrowserList = "settings.browser-list"
    static let settingsBrowserRefresh = "settings.browser-refresh"
    static let settingsBrowserReset = "settings.browser-reset"
    static let settingsBrowserShowAll = "settings.browser-show-all"
    static let settingsProfileScriptSetup = "settings.profile-script.setup"
    static let settingsProfileScriptSheet = "settings.profile-script.sheet"
    static let settingsProfileScriptInstall = "settings.profile-script.install"
    static let settingsProfileScriptInstalled = "settings.profile-script.installed"

    static let onboardingDefaultBrowserStatus = "onboarding.default-browser.status"
    static let onboardingDefaultBrowserAction = "onboarding.default-browser.action"
    static let onboardingDefaultBrowserError = "onboarding.default-browser.error"
    static let onboardingDone = "onboarding.done"

    static let pickerDestination = "picker.destination"
    static let pickerContent = "picker.content"
    static let pickerEmptyState = "picker.empty-state"
    static let pickerScrollArea = "picker.scroll-area"
    static let pickerRememberHost = "picker.remember-host"
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

    static func pickerShortcutLetter(targetIdentifier: String) -> String {
        "picker.shortcut-letter.\(targetIdentifier)"
    }

    static func pickerShortcutNumber(targetIdentifier: String) -> String {
        "picker.shortcut-number.\(targetIdentifier)"
    }

    static func settingsProfileBrowser(
        bundleIdentifier: String
    ) -> String {
        "settings.profile-browser.\(bundleIdentifier)"
    }

    static func settingsRule(
        host: String
    ) -> String {
        "settings.rule.\(host)"
    }

    static func settingsRuleRemove(
        host: String
    ) -> String {
        "settings.rule.\(host).remove"
    }
}
