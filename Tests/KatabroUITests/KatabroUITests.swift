import XCTest

// UI fixture coverage intentionally shares launch and assertion helpers.
// swiftlint:disable file_length
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
        let aboutTab = application.radioButtons["settings.pane.about"]

        assertExists(application.scrollViews["settings.general.form"])
        assertExists(generalTab)
        assertExists(browsersTab)
        assertExists(aboutTab)
        XCTAssertTrue(isControlOn(generalTab))
        XCTAssertFalse(isControlOn(browsersTab))
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
        let expectedStatus =
            "Browser order and picker shortcuts stay on this Mac because iCloud sync is unavailable for this build."
        XCTAssertTrue(
            status.label == expectedStatus
                || status.value as? String == expectedStatus
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
        let aboutTab = application.radioButtons["settings.pane.about"]

        assertExists(application.scrollViews["settings.general.form"])
        browsersTab.click()
        assertExists(application.scrollViews["settings.browsers.form"])
        assertExists(
            application.descendants(matching: .any)[
                "settings.browser-row.com.apple.Safari.visibility"
            ]
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

// swiftlint:enable file_length
