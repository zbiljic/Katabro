import XCTest

// UI fixture coverage intentionally shares launch and assertion helpers.
// swiftlint:disable file_length type_body_length
final class KatabroUITests: XCTestCase {
    @MainActor
    func testSettingsNormalState() {
        let application = launch(
            surface: "settings",
            state: "normal"
        )
        defer {
            application.terminate()
        }

        let generalTab = application.radioButtons["settings.pane.general"]
        let browsersTab = application.radioButtons["settings.pane.browsers"]
        let rulesTab = application.radioButtons["settings.pane.rules"]
        let aboutTab = application.radioButtons["settings.pane.about"]

        assertExists(application.scrollViews["settings.general.form"])
        assertExists(generalTab)
        assertExists(browsersTab)
        assertExists(rulesTab)
        assertExists(aboutTab)
        XCTAssertTrue(isControlOn(generalTab))
        XCTAssertFalse(isControlOn(browsersTab))
        XCTAssertFalse(isControlOn(rulesTab))
        XCTAssertFalse(isControlOn(aboutTab))
        assertExists(
            application.staticTexts["settings.default-browser.status"]
        )
        assertExists(
            application.switches["settings.login-item.toggle"]
        )
        assertExists(
            application.staticTexts["settings.icloud.status"]
        )
        let syncStatus = application.staticTexts["settings.icloud.status"]
        XCTAssertEqual(
            syncStatus.value as? String,
            "Browser order, picker shortcuts, and exact-host rules sync through Shared Katabro."
        )
        let folderName = application.staticTexts["settings.sync.folder-name"]
        assertExists(folderName)
        XCTAssertEqual(folderName.value as? String, "~/Documents/Shared Katabro")
        assertExists(application.staticTexts["Location"])
        browsersTab.click()

        assertExists(application.scrollViews["settings.browsers.form"])
        let browserListExists =
            application.outlines["settings.browser-list"].exists ||
            application.tables["settings.browser-list"].exists ||
            application.scrollViews["settings.browser-list"].exists
        XCTAssertTrue(
            browserListExists
        )
        attachScreenshot(
            named: "Settings-normal-browsers-system",
            from: application
        )
    }

    @MainActor
    func testSettingsFixtureStates() {
        let browserStates = [
            "loading",
            "no-browsers",
            "browser-discovery-error",
            "many-browsers",
        ]

        var previousApplication: XCUIApplication?

        for state in browserStates {
            previousApplication?.terminate()
            let application = launch(
                surface: "settings",
                state: state
            )
            previousApplication = application

            assertExists(
                application.scrollViews["settings.browsers.form"],
                message: "Browsers did not appear for fixture state \(state)"
            )
            XCTAssertTrue(
                isControlOn(
                    application.radioButtons["settings.pane.browsers"]
                )
            )
            attachScreenshot(
                named: "Settings-browsers-\(state)-system",
                from: application
            )
        }

        previousApplication?.terminate()
    }

    @MainActor
    func testSettingsServiceErrorsOpenGeneral() {
        let application = launch(
            surface: "settings",
            state: "service-errors"
        )
        defer {
            application.terminate()
        }

        assertExists(application.scrollViews["settings.general.form"])
        XCTAssertTrue(
            isControlOn(
                application.radioButtons["settings.pane.general"]
            )
        )
        assertExists(
            application.staticTexts["settings.default-browser.error"]
        )
        let status = application.staticTexts["settings.icloud.status"]
        assertExists(status)
        let expectedStatus = "Folder sync is unavailable; local settings remain active."
        XCTAssertTrue(
            status.label == expectedStatus
                || status.value as? String == expectedStatus
        )
    }

    @MainActor
    func testSyncDisclosureAndAdoptionActions() {
        let application = launch(surface: "settings", state: "normal")
        defer { application.terminate() }
        let choose = application.buttons["settings.sync.choose-folder"]
        assertExists(choose)
        choose.click()
        dialogButton(
            application,
            identifier: "settings.sync.disclosure.cancel",
            label: "Cancel"
        ).click()
        XCTAssertTrue(choose.exists)
        choose.click()
        dialogButton(
            application,
            identifier: "settings.sync.disclosure.continue",
            label: "Continue"
        ).click()
        let adoptionCancel = dialogButton(
            application,
            identifier: "settings.sync.adoption.cancel",
            label: "Cancel"
        )
        XCTAssertTrue(adoptionCancel.exists)
        adoptionCancel.click()
        XCTAssertEqual(application.popUpButtons["settings.sync.method"].value as? String, "Folder")
    }

    @MainActor
    func testSyncAdoptsFolderSettings() {
        let application = launch(surface: "settings", state: "normal")
        defer { application.terminate() }
        application.buttons["settings.sync.choose-folder"].click()
        dialogButton(
            application,
            identifier: "settings.sync.disclosure.continue",
            label: "Continue"
        ).click()
        dialogButton(
            application,
            identifier: "settings.sync.adoption.use-folder",
            label: "Use Folder Settings"
        ).click()
        XCTAssertEqual(application.popUpButtons["settings.sync.method"].value as? String, "Folder")
        XCTAssertTrue(
            (application.staticTexts["settings.icloud.status"].value as? String)?.contains(
                "exact-host rules sync through Shared Katabro"
            ) == true
        )
    }

    @MainActor
    func testSyncReplacesFolderSettings() {
        let application = launch(surface: "settings", state: "normal")
        defer { application.terminate() }
        application.buttons["settings.sync.choose-folder"].click()
        dialogButton(
            application,
            identifier: "settings.sync.disclosure.continue",
            label: "Continue"
        ).click()
        dialogButton(
            application,
            identifier: "settings.sync.adoption.replace-file",
            label: "Replace File with This Mac"
        ).click()
        XCTAssertEqual(application.popUpButtons["settings.sync.method"].value as? String, "Folder")
        XCTAssertTrue(
            (application.staticTexts["settings.icloud.status"].value as? String)?.contains("Shared Katabro") == true
        )
    }

    @MainActor
    func testSyncErrorIsActionableWithoutOpeningAPanel() {
        let application = launch(surface: "settings", state: "service-errors")
        defer { application.terminate() }
        let choose = application.buttons["settings.sync.choose-folder"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5))
        choose.click()
        let continueButton = application.buttons["settings.sync.disclosure.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()
        let error = application.staticTexts["settings.sync.error"]
        assertExists(error)
        guard let errorValue = error.value as? String else {
            XCTFail("Expected settings.sync.error to expose a string value")
            return
        }
        XCTAssertFalse(errorValue.isEmpty)
        XCTAssertEqual(
            errorValue,
            "Folder access is unavailable. Choose the folder again to recover."
        )
    }

    @MainActor
    func testSettingsPaneSwitching() {
        let application = launch(
            surface: "settings",
            state: "normal"
        )
        defer {
            application.terminate()
        }

        let generalTab = application.radioButtons["settings.pane.general"]
        let browsersTab = application.radioButtons["settings.pane.browsers"]
        let rulesTab = application.radioButtons["settings.pane.rules"]
        let aboutTab = application.radioButtons["settings.pane.about"]

        assertExists(application.scrollViews["settings.general.form"])
        browsersTab.click()
        assertExists(application.scrollViews["settings.browsers.form"])
        assertExists(
            application.descendants(matching: .any)[
                "settings.browser-row.com.apple.Safari.visibility"
            ]
        )
        rulesTab.click()
        assertExists(application.scrollViews["settings.rules.form"])
        assertExists(
            application.descendants(matching: .any)["settings.rule.example.com"]
        )
        aboutTab.click()
        assertExists(application.scrollViews["settings.about.content"])
        assertExists(application.links["settings.about.link.repository"])
        generalTab.click()
        assertExists(application.scrollViews["settings.general.form"])
        assertExists(
            application.switches["settings.login-item.toggle"]
        )
    }

    @MainActor
    func testSettingsLightAndDarkAppearances() {
        var previousApplication: XCUIApplication?

        for appearance in ["light", "dark"] {
            previousApplication?.terminate()
            let application = launch(
                surface: "settings",
                state: "normal",
                appearance: appearance
            )
            previousApplication = application

            assertExists(application.scrollViews["settings.general.form"])
            attachScreenshot(
                named: "Settings-general-normal-\(appearance)",
                from: application
            )
            application.radioButtons["settings.pane.browsers"].click()
            assertExists(application.scrollViews["settings.browsers.form"])
            attachScreenshot(
                named: "Settings-browsers-normal-\(appearance)",
                from: application
            )
            application.radioButtons["settings.pane.rules"].click()
            assertExists(application.scrollViews["settings.rules.form"])
            attachScreenshot(
                named: "Settings-rules-populated-\(appearance)",
                from: application
            )
            application.radioButtons["settings.pane.about"].click()
            assertExists(application.scrollViews["settings.about.content"])
            attachScreenshot(
                named: "Settings-about-normal-\(appearance)",
                from: application
            )
        }

        previousApplication?.terminate()
    }

    @MainActor
    func testLoginItemFixtureIsInteractive() {
        let application = launch(
            surface: "settings",
            state: "normal"
        )
        let toggle = application.switches["settings.login-item.toggle"]
        defer {
            application.terminate()
        }

        assertExists(
            toggle
        )

        let initialValue = String(
            describing: toggle.value
        )
        toggle.click()
        let updatedValue = String(
            describing: toggle.value
        )

        XCTAssertNotEqual(
            updatedValue,
            initialValue
        )
    }

    @MainActor
    func testBrowserVisibilityControls() {
        let application = launch(
            surface: "settings",
            state: "normal"
        )
        defer {
            application.terminate()
        }
        let safari = application.descendants(
            matching: .any
        )["settings.browser-row.com.apple.Safari.visibility"]
        let chrome = application.descendants(
            matching: .any
        )["settings.browser-row.com.google.Chrome.visibility"]
        let showAll = application.buttons["settings.browser-show-all"]

        application.radioButtons["settings.pane.browsers"].click()

        assertExists(safari)
        assertExists(chrome)
        assertExists(showAll)
        XCTAssertTrue(isControlOn(safari))
        XCTAssertTrue(isControlOn(chrome))
        XCTAssertFalse(showAll.isEnabled)

        chrome.click()

        XCTAssertFalse(isControlOn(chrome))
        XCTAssertTrue(showAll.isEnabled)

        showAll.click()

        XCTAssertTrue(isControlOn(chrome))
        XCTAssertFalse(showAll.isEnabled)
    }

    @MainActor
    func testManyBrowserVisibilityControlsScrollToLateRows() {
        let application = launch(
            surface: "settings",
            state: "many-browsers"
        )
        defer {
            application.terminate()
        }
        let lateBrowser = application.descendants(
            matching: .any
        )["settings.browser-row.com.apple.SafariTechnologyPreview.visibility"]
        let browserList = application.descendants(
            matching: .any
        )["settings.browser-list"]

        assertExists(browserList)

        for _ in 0 ..< 8 where !lateBrowser.isHittable {
            browserList.swipeUp()
        }

        assertExists(
            lateBrowser,
            message: "The final browser visibility control was not reachable by scrolling"
        )
        XCTAssertTrue(lateBrowser.isHittable)
        XCTAssertTrue(isControlOn(lateBrowser))
    }

    @MainActor
    func testOnboardingAndPickerReviewSurfaces() {
        let surfaces = [
            ("onboarding", "onboarding.done"),
            ("picker", "picker.browser.com.apple.Safari"),
        ]

        var previousApplication: XCUIApplication?

        for (surface, identifier) in surfaces {
            previousApplication?.terminate()
            let application = launch(
                surface: surface,
                state: "normal"
            )
            previousApplication = application

            assertExists(
                application.descendants(
                    matching: .any
                )[identifier],
                message: "The \(surface) review surface did not appear"
            )
            attachScreenshot(
                named: surface.capitalized,
                from: application
            )
        }

        previousApplication?.terminate()
    }

    @MainActor
    func testOnboardingServiceErrorsReviewSurface() {
        let application = launch(
            surface: "onboarding",
            state: "service-errors"
        )
        defer {
            application.terminate()
        }

        for identifier in [
            "onboarding.default-browser.status",
            "onboarding.default-browser.action",
            "onboarding.default-browser.error",
            "onboarding.done",
        ] {
            assertExists(
                application.descendants(
                    matching: .any
                )[identifier]
            )
        }
        attachScreenshot(
            named: "Onboarding-service-errors",
            from: application
        )
    }
}

extension KatabroUITests {
    @MainActor
    func testFilePickerLightAndDark() {
        var previousApplication: XCUIApplication?

        for appearance in ["light", "dark"] {
            previousApplication?.terminate()
            let application = launch(
                surface: "picker",
                state: "file-url",
                appearance: appearance
            )
            previousApplication = application

            let destination = application.descendants(matching: .any)[
                "picker.destination"
            ]
            let remember = application.descendants(matching: .any)[
                "picker.remember-host"
            ]
            let safari = application.descendants(matching: .any)[
                "picker.browser.com.apple.Safari"
            ]
            let receipt = application.descendants(matching: .any)[
                "picker.selection-receipt"
            ]

            assertExists(destination)
            XCTAssertTrue(
                (destination.value as? String)?.contains("file:///fixture/index.html") == true
                    || destination.label.contains("file:///fixture/index.html")
            )
            XCTAssertFalse(remember.exists)
            assertExists(safari)
            assertExists(receipt)
            safari.click()
            assertReceipt(receipt, equals: "Safari selected 1 time")
            attachScreenshot(
                named: "Picker-file-url-\(appearance)",
                from: application
            )
        }

        previousApplication?.terminate()
    }

    @MainActor
    func testPickerRememberHostControl() {
        let application = launch(
            surface: "picker",
            state: "normal"
        )
        defer {
            application.terminate()
        }
        let checkbox = application.descendants(matching: .any)[
            "picker.remember-host"
        ]
        let receipt = application.descendants(matching: .any)[
            "picker.selection-receipt"
        ]

        assertExists(checkbox)
        assertExists(receipt)
        XCTAssertFalse(isControlOn(checkbox))
        application.typeKey(
            "r",
            modifierFlags: [.command, .shift]
        )
        XCTAssertTrue(isControlOn(checkbox))
        XCTAssertEqual(receipt.value as? String, "No browser selected")
        application.typeKey(
            "r",
            modifierFlags: [.command, .shift]
        )
        XCTAssertFalse(isControlOn(checkbox))
        checkbox.click()
        XCTAssertTrue(isControlOn(checkbox))
        application.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(isControlOn(checkbox))
    }

    @MainActor
    func testRulesManagement() {
        let application = launch(
            surface: "settings",
            state: "normal",
            preferencesSuite: "rules-\(UUID().uuidString)",
            resetsPreferences: true
        )
        defer {
            application.terminate()
        }
        let exampleRow = application.descendants(matching: .any)[
            "settings.rule.example.com"
        ]
        let developerRow = application.descendants(matching: .any)[
            "settings.rule.developer.apple.com"
        ]

        application.radioButtons["settings.pane.rules"].click()
        assertExists(application.scrollViews["settings.rules.form"])
        assertExists(exampleRow)
        assertExists(developerRow)

        let exampleRemoveButton = application
            .descendants(matching: .any)["settings.rule.example.com.remove"]
        exampleRemoveButton.click()
        XCTAssertFalse(exampleRow.exists)
        XCTAssertTrue(developerRow.exists)

        let removeAll = application.buttons["settings.rules.remove-all"]
        assertExists(removeAll)
        removeAll.click()
        let cancel = application.sheets.buttons["Cancel"]
        assertExists(cancel)
        cancel.click()
        XCTAssertTrue(developerRow.exists)

        removeAll.click()
        let confirmRemoveAll = application.sheets.buttons["Remove All"]
        assertExists(confirmRemoveAll)
        confirmRemoveAll.click()
        assertExists(
            application.descendants(matching: .any)["settings.rules.empty"]
        )
    }

    @MainActor
    func testPickerAndRulesLightAndDarkScreenshots() {
        var previousApplication: XCUIApplication?

        for appearance in ["light", "dark"] {
            for state in ["normal", "many-browsers"] {
                previousApplication?.terminate()
                let application = launch(
                    surface: "picker",
                    state: state,
                    appearance: appearance
                )
                previousApplication = application
                assertExists(
                    application.descendants(matching: .any)["picker.remember-host"]
                )
                attachScreenshot(
                    named: "Picker-\(state)-\(appearance)",
                    from: application
                )
            }

            previousApplication?.terminate()
            let application = launch(
                surface: "settings",
                state: "normal",
                appearance: appearance,
                preferencesSuite: "rules-empty-\(appearance)-\(UUID().uuidString)",
                resetsPreferences: true
            )
            previousApplication = application
            application.radioButtons["settings.pane.rules"].click()
            assertExists(application.scrollViews["settings.rules.form"])
            attachScreenshot(
                named: "Settings-rules-populated-standalone-\(appearance)",
                from: application
            )
            application.buttons["settings.rules.remove-all"].click()
            let confirmRemoveAll = application.sheets.buttons["Remove All"]
            assertExists(confirmRemoveAll)
            confirmRemoveAll.click()
            assertExists(
                application.descendants(matching: .any)["settings.rules.empty"]
            )
            attachScreenshot(
                named: "Settings-rules-empty-\(appearance)",
                from: application
            )
        }

        previousApplication?.terminate()
    }

    @MainActor
    func testLauncherHelperSetupSheet() {
        let application = launch(
            surface: "settings",
            state: "script-setup"
        )
        defer {
            application.terminate()
        }

        let setupButton = application.buttons["settings.profile-script.setup"]
        assertExists(setupButton)
        setupButton.click()

        assertExists(
            application.descendants(matching: .any)[
                "settings.profile-script.sheet"
            ]
        )
        let installButton = application.buttons["settings.profile-script.install"]
        assertExists(installButton)
        XCTAssertEqual(installButton.label, "Install open.sh…")
        attachScreenshot(
            named: "Settings-launcher-helper-setup",
            from: application
        )

        installButton.click()
        assertExists(
            application.descendants(matching: .any)[
                "settings.profile-script.installed"
            ]
        )
    }

    @MainActor
    func testLauncherHelperReplacementSheet() {
        let application = launch(
            surface: "settings",
            state: "script-replace"
        )
        defer {
            application.terminate()
        }

        let replaceButton = application.buttons["settings.profile-script.setup"]
        assertExists(replaceButton)
        XCTAssertEqual(replaceButton.label, "Replace with Current Version…")
        replaceButton.click()

        let sheetTitle = application.staticTexts["settings.profile-script.sheet"]
        assertExists(sheetTitle)
        XCTAssertTrue(
            sheetTitle.label.contains("Replace Launcher Helper")
                || String(describing: sheetTitle.value).contains("Replace Launcher Helper")
        )
        let installButton = application.buttons["settings.profile-script.install"]
        assertExists(installButton)
        XCTAssertEqual(installButton.label, "Replace open.sh…")
        XCTAssertFalse(
            application.descendants(matching: .any)[
                "settings.profile-script.installed"
            ].exists
        )
        attachScreenshot(
            named: "Settings-launcher-helper-replacement",
            from: application
        )
    }

    // swiftlint:disable function_body_length
    @MainActor
    func testPickerLetterShortcuts() {
        let preferencesSuite = "picker-shortcuts-\(UUID().uuidString)"
        var application = launch(
            surface: "settings",
            state: "normal",
            preferencesSuite: preferencesSuite,
            resetsPreferences: true
        )
        application.radioButtons["settings.pane.browsers"].click()

        let safariShortcut = application.descendants(matching: .any)[
            "settings.browser-row.com.apple.Safari.shortcut"
        ]
        let chromeShortcut = application.descendants(matching: .any)[
            "settings.browser-row.com.google.Chrome.shortcut"
        ]
        let chromeVisibility = application.descendants(matching: .any)[
            "settings.browser-row.com.google.Chrome.visibility"
        ]
        assertExists(safariShortcut)
        assertExists(chromeShortcut)
        XCTAssertEqual(shortcutValue(safariShortcut), "S")
        XCTAssertEqual(shortcutValue(chromeShortcut), "C")

        enterShortcut("s", in: chromeShortcut)
        XCTAssertEqual(shortcutValue(chromeShortcut), "S")
        XCTAssertEqual(shortcutValue(safariShortcut), "—")

        chromeVisibility.click()
        XCTAssertFalse(isControlOn(chromeVisibility))
        application.terminate()

        application = launch(
            surface: "settings",
            state: "normal",
            preferencesSuite: preferencesSuite
        )
        application.radioButtons["settings.pane.browsers"].click()
        let persistedChromeShortcut = application.descendants(matching: .any)[
            "settings.browser-row.com.google.Chrome.shortcut"
        ]
        let persistedChromeVisibility = application.descendants(matching: .any)[
            "settings.browser-row.com.google.Chrome.visibility"
        ]
        let persistedChromeShortcutClear = application.descendants(matching: .any)[
            "settings.browser-row.com.google.Chrome.shortcut-clear"
        ]
        assertExists(persistedChromeShortcut)
        assertExists(persistedChromeShortcutClear)
        XCTAssertEqual(shortcutValue(persistedChromeShortcut), "S")
        XCTAssertFalse(isControlOn(persistedChromeVisibility))

        persistedChromeShortcutClear.click()
        XCTAssertEqual(shortcutValue(persistedChromeShortcut), "—")
        persistedChromeShortcut.typeKey("1", modifierFlags: [])
        XCTAssertEqual(shortcutValue(persistedChromeShortcut), "—")
        enterShortcut("s", in: persistedChromeShortcut)
        persistedChromeVisibility.click()
        XCTAssertTrue(isControlOn(persistedChromeVisibility))
        application.terminate()

        application = launch(
            surface: "picker",
            state: "normal",
            preferencesSuite: preferencesSuite
        )
        var receipt = application.descendants(matching: .any)["picker.selection-receipt"]
        assertExists(receipt)
        application.typeKey("s", modifierFlags: [])
        assertReceipt(receipt, equals: "Google Chrome selected 1 time")
        application.terminate()

        application = launch(
            surface: "picker",
            state: "normal",
            preferencesSuite: preferencesSuite
        )
        receipt = application.descendants(matching: .any)["picker.selection-receipt"]
        assertExists(receipt)
        application.typeKey("2", modifierFlags: [])
        assertReceipt(receipt, equals: "Google Chrome selected 1 time")
        application.typeKey("1", modifierFlags: [])
        assertReceipt(receipt, equals: "Safari selected 2 times")
        application.terminate()

        for modifiers in [
            XCUIElement.KeyModifierFlags.shift,
            XCUIElement.KeyModifierFlags.capsLock,
        ] {
            application = launch(
                surface: "picker",
                state: "normal",
                preferencesSuite: preferencesSuite
            )
            receipt = application.descendants(matching: .any)["picker.selection-receipt"]
            assertExists(receipt)
            application.typeKey("s", modifierFlags: modifiers)
            assertReceipt(receipt, equals: "Google Chrome selected 1 time")
            application.terminate()
        }

        application = launch(
            surface: "picker",
            state: "normal",
            preferencesSuite: preferencesSuite
        )
        receipt = application.descendants(matching: .any)["picker.selection-receipt"]
        assertExists(receipt)
        for modifiers in [
            XCUIElement.KeyModifierFlags.command,
            XCUIElement.KeyModifierFlags.option,
            XCUIElement.KeyModifierFlags.control,
        ] {
            application.typeKey("s", modifierFlags: modifiers)
            XCTAssertEqual(receipt.value as? String, "No browser selected")
        }
        attachScreenshot(
            named: "Picker-letter-shortcuts",
            from: application
        )
        application.terminate()
    }

    // swiftlint:enable function_body_length

    @MainActor
    func testPickerKeyboardSelection() {
        let application = launch(
            surface: "picker",
            state: "normal"
        )
        defer {
            application.terminate()
        }
        let receipt = application.descendants(
            matching: .any
        )["picker.selection-receipt"]
        let cancellationReceipt = application.descendants(
            matching: .any
        )["picker.cancellation-receipt"]

        assertExists(receipt)
        assertExists(cancellationReceipt)
        XCTAssertEqual(
            receipt.value as? String,
            "No browser selected"
        )

        application.typeKey(" ", modifierFlags: [])

        let selectionRecorded = NSPredicate(
            format: "value ENDSWITH %@",
            " selected 1 time"
        )
        expectation(
            for: selectionRecorded,
            evaluatedWith: receipt
        )
        waitForExpectations(timeout: 5)
        XCTAssertTrue(
            (receipt.value as? String)?.hasSuffix(
                " selected 1 time"
            ) == true
        )

        application.typeKey(.downArrow, modifierFlags: [])
        application.typeKey(.return, modifierFlags: [])
        assertReceipt(
            receipt,
            equals: "Google Chrome selected 2 times"
        )

        application.typeKey(.escape, modifierFlags: [])
        assertReceipt(
            cancellationReceipt,
            equals: "Picker cancelled 1 time"
        )
    }

    @MainActor
    func testSettingsAboutPane() {
        let application = launch(
            surface: "settings",
            state: "normal"
        )
        defer {
            application.terminate()
        }

        let aboutTab = application.radioButtons["settings.pane.about"]
        aboutTab.click()

        assertExists(application.scrollViews["settings.about.content"])
        assertExists(application.staticTexts["settings.about.version"])
        assertExists(application.links["settings.about.link.repository"])
        assertExists(application.links["settings.about.link.issues"])
        assertExists(application.links["settings.about.link.license"])
        XCTAssertTrue(isControlOn(aboutTab))
    }
}

private extension KatabroUITests {
    @MainActor
    func launch(
        surface: String,
        state: String,
        appearance: String = "system",
        preferencesSuite: String? = nil,
        resetsPreferences: Bool = false
    ) -> XCUIApplication {
        let application = XCUIApplication()
        application.launchArguments = [
            "--ui-review",
            surface,
            "--ui-state",
            state,
            "--ui-appearance",
            appearance,
        ]
        if let preferencesSuite {
            application.launchArguments += [
                "--ui-preferences-suite",
                preferencesSuite,
            ]
        }
        if resetsPreferences {
            application.launchArguments.append(
                "--ui-reset-preferences"
            )
        }
        application.launch()
        return application
    }

    @MainActor
    func enterShortcut(
        _ value: String,
        in shortcutField: XCUIElement
    ) {
        shortcutField.click()
        shortcutField.typeText(value)
    }

    @MainActor
    func shortcutValue(
        _ shortcutPicker: XCUIElement
    ) -> String {
        if let value = shortcutPicker.value as? String {
            return value.isEmpty ? "—" : value
        }

        return String(describing: shortcutPicker.value)
    }

    @MainActor
    func assertReceipt(
        _ receipt: XCUIElement,
        equals expectedValue: String
    ) {
        let predicate = NSPredicate(
            format: "value == %@",
            expectedValue
        )
        expectation(
            for: predicate,
            evaluatedWith: receipt
        )
        waitForExpectations(timeout: 5)
        XCTAssertEqual(receipt.value as? String, expectedValue)
    }

    @MainActor
    func attachScreenshot(
        named name: String,
        from application: XCUIApplication
    ) {
        let attachment = XCTAttachment(
            screenshot: application.screenshot()
        )
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func isControlOn(
        _ element: XCUIElement
    ) -> Bool {
        if let number = element.value as? NSNumber {
            return number.boolValue
        }

        let value = String(
            describing: element.value
        ).lowercased()
        return ["1", "true", "on", "checked"].contains(value)
    }

    @MainActor
    func dialogButton(
        _ application: XCUIApplication,
        identifier: String,
        label: String
    ) -> XCUIElement {
        let identified = application.buttons[identifier]
        if identified.exists {
            return identified
        }
        let labeled = application.buttons.matching(
            NSPredicate(format: "label == %@", label)
        ).allElementsBoundByIndex
        return labeled.first ?? application.buttons[label]
    }

    @MainActor
    func assertExists(
        _ element: XCUIElement,
        message: String = "Expected UI element did not appear"
    ) {
        let exists = element.waitForExistence(
            timeout: 5
        )
        XCTAssertTrue(
            exists,
            message
        )
    }
}

// swiftlint:enable file_length type_body_length
