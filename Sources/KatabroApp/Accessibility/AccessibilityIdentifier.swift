enum AccessibilityIdentifier {
    static let menuOpenClipboard = "menu.open-url-from-clipboard"
    static let menuCaptureScreenURLs = "menu.capture-screen-urls"
    static let menuClipboardURLPreview = "menu.clipboard-url-preview"
    static let menuSetupRequired = "menu.setup-required"
    static let menuSetupGuide = "menu.setup-guide"
    static let menuSettings = "menu.settings"
    static let menuMore = "menu.more"
    static let menuRules = "menu.rules"
    static let menuAbout = "menu.about"
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
    static let settingsRecentRoutesSection = "settings.recent-routes.section"
    static let settingsRecentRoutesEmpty = "settings.recent-routes.empty"
    static let settingsRecentRoutesClear = "settings.recent-routes.clear"
    static let settingsRecentRoutesShowAll = "settings.recent-routes.show-all"
    static let settingsRecentRoutesShowLess = "settings.recent-routes.show-less"
    static let settingsRecentRoutesPrivacy = "settings.recent-routes.privacy"
    static let settingsRecentRoutesRuleConfirm = "settings.recent-routes.rule-confirm"
    static let settingsRecentRoutesRuleCancel = "settings.recent-routes.rule-cancel"
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
    static let settingsMenuBarSection = "settings.menu-bar.section"
    static let settingsMenuBarShortcutToggle = "settings.menu-bar.shortcut-toggle"
    static let settingsMenuBarShortcutField = "settings.menu-bar.shortcut-field"
    static let settingsMenuBarShortcutStatus = "settings.menu-bar.shortcut-status"
    static let settingsClipboardURLSection = "settings.clipboard-url.section"
    static let settingsClipboardURLShortcutToggle = "settings.clipboard-url.shortcut-toggle"
    static let settingsClipboardURLShortcutField = "settings.clipboard-url.shortcut-field"
    static let settingsClipboardURLShortcutStatus = "settings.clipboard-url.shortcut-status"
    static let settingsScreenURLCaptureSection = "settings.screen-url-capture.section"
    static let settingsScreenURLCaptureToggle = "settings.screen-url-capture.toggle"
    static let settingsScreenURLCaptureUnavailable = "settings.screen-url-capture.unavailable"
    static let settingsScreenURLShortcutToggle = "settings.screen-url-capture.shortcut-toggle"
    static let settingsScreenURLShortcutField = "settings.screen-url-capture.shortcut-field"
    static let settingsScreenURLShortcutStatus = "settings.screen-url-capture.shortcut-status"
    static let settingsScreenURLPermissionStatus = "settings.screen-url-capture.permission-status"
    static let settingsScreenURLPermissionGranted = "settings.screen-url-capture.permission-authorized-status"
    static let settingsScreenURLRequestAccess = "settings.screen-url-capture.request-access"
    static let settingsScreenURLOpenSystemSettings = "settings.screen-url-capture.open-system-settings"
    static let screenURLPicker = "screen-url-picker"
    static let screenURLEmptyState = "screen-url-picker.empty-state"
    static let screenURLLoadingState = "screen-url-picker.loading-state"
    static let screenURLPermissionState = "screen-url-picker.permission-state"
    static let screenURLOpenSystemSettings = "screen-url-picker.open-system-settings"
    static let screenURLCaptureFailureState = "screen-url-picker.capture-failure-state"
    static let screenURLVisionUnavailableState = "screen-url-picker.vision-unavailable-state"
    static let screenURLOpenAll = "screen-url-picker.open-all"
    static let screenURLSelectionReceipt = "screen-url-picker.selection-receipt"
    static let screenURLCancellationReceipt = "screen-url-picker.cancellation-receipt"

    static func screenURLRow(_ index: Int) -> String {
        "screen-url-picker.row.\(index)"
    }

    static func screenURLShortcut(_ index: Int) -> String {
        "screen-url-picker.shortcut.\(index)"
    }

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
    static let pickerCopyLink = "picker.copy-link"
    static let pickerCopyReceipt = "picker.copy-receipt"
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

    static func settingsRecentRoutePreviewRow(
        requestID: String
    ) -> String {
        "settings.recent-routes.preview-row.\(requestID)"
    }

    static func settingsRecentRouteExpandedRow(
        requestID: String
    ) -> String {
        "settings.recent-routes.expanded-row.\(requestID)"
    }

    static func settingsRecentRouteRuleAction(
        requestID: String
    ) -> String {
        "settings.recent-routes.rule-action.\(requestID)"
    }

    static func settingsRecentRouteRuleExists(
        requestID: String
    ) -> String {
        "settings.recent-routes.rule-exists.\(requestID)"
    }
}
