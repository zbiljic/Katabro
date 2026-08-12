import XCTest

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
            "Browser order stays on this Mac because iCloud sync is unavailable for this build."
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
        appearance: String = "system"
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
        application.launch()
        return application
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
