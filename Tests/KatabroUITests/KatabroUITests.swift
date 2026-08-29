import XCTest

// UI fixture coverage intentionally shares launch and assertion helpers.
// swiftlint:disable file_length type_body_length
final class KatabroUITests: XCTestCase {
    enum ScrollDirection {
        case up
        case down
    }

    @MainActor
    func testScreenURLPickerStates() {
        let expected = [
            ("normal", "screen-url-picker.open-all", "Open all 3 URLs"),
            ("loading", "screen-url-picker.loading-state", "URLs Found on Screen"),
            ("no-urls", "screen-url-picker.empty-state", "No Web URLs Found"),
            ("screen-capture-denied", "screen-url-picker.permission-state", "Screen Recording Access Required"),
            ("service-errors", "screen-url-picker.capture-failure-state", "Couldn’t Capture Screen"),
            (
                "vision-unavailable",
                "screen-url-picker.vision-unavailable-state",
                "On-device Text Recognition Unavailable"
            ),
        ]
        for appearance in ["light", "dark"] {
            for (state, identifier, title) in expected {
                let application = launch(surface: "screen-urls", state: state, appearance: appearance)
                assertExists(application.descendants(matching: .any)["screen-url-picker"])
                assertExists(application.descendants(matching: .any)[identifier])
                if state == "normal" {
                    let openAll = application.descendants(matching: .any)["screen-url-picker.open-all"]
                    assertExists(openAll)
                    XCTAssertEqual(openAll.label, "Open all 3 detected URLs")
                } else if state == "screen-capture-denied" {
                    XCTAssertTrue(application.staticTexts[title].exists)
                    assertExists(application.buttons["screen-url-picker.open-system-settings"])
                } else {
                    XCTAssertTrue(application.staticTexts[title].exists)
                }
                XCTAssertTrue(application.staticTexts["Esc Cancel"].exists)
                XCTAssertTrue(application.staticTexts["↑↓ Select"].exists)
                XCTAssertTrue(application.staticTexts["↩ Open"].exists)
                XCTAssertLessThan(
                    application.staticTexts["Esc Cancel"].frame.minX,
                    application.staticTexts["↑↓ Select"].frame.minX
                )
                XCTAssertLessThan(
                    application.staticTexts["↑↓ Select"].frame.minX,
                    application.staticTexts["↩ Open"].frame.minX
                )
                attachScreenshot(named: "Screen-URLs-\(state)-\(appearance)", from: application)
                application.terminate()
            }
        }
    }

    @MainActor
    func testScreenURLPickerShortcutPresentation() {
        for appearance in ["light", "dark"] {
            let many = launch(surface: "screen-urls", state: "many-urls", appearance: appearance)
            let scroll = many.scrollViews.firstMatch
            assertExists(scroll)
            many.typeKey(.downArrow, modifierFlags: [])
            many.typeKey(.return, modifierFlags: [])
            let receipt = many.staticTexts["screen-url-picker.selection-receipt"]
            assertExists(receipt)
            XCTAssertTrue((receipt.value as? String)?.hasPrefix("Selections: 1 — URL ") == true)
            attachScreenshot(named: "Screen-URLs-many-urls-\(appearance)", from: many)
            assertManyURLShortcutPresentation(in: many, scroll: scroll)
            assertExists(many.descendants(matching: .any)["screen-url-picker.open-all"])
            many.terminate()
        }
    }

    @MainActor
    func testScreenURLPickerKeyboardSelection() {
        for key in 1 ... 9 {
            let application = launch(surface: "screen-urls", state: "many-urls")
            assertExists(application.descendants(matching: .any)["screen-url-picker"].firstMatch)
            application.typeText("\(key)")
            assertReceipt(
                application.staticTexts["screen-url-picker.selection-receipt"],
                equals: "Selections: 1 — URL \(key)"
            )
            application.typeText("\(key)")
            assertReceipt(
                application.staticTexts["screen-url-picker.selection-receipt"],
                equals: "Selections: 1 — URL \(key)"
            )
            application.terminate()
        }

        var application = launch(surface: "screen-urls", state: "normal")
        application.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(application.descendants(matching: .any)["screen-url-picker.row.1"].isSelected)
        application.typeKey(.upArrow, modifierFlags: [])
        XCTAssertTrue(application.descendants(matching: .any)["screen-url-picker.row.0"].isSelected)
        application.typeKey(.downArrow, modifierFlags: [])
        application.typeKey(.space, modifierFlags: [])
        assertReceipt(application.staticTexts["screen-url-picker.selection-receipt"], equals: "Selections: 1 — URL 2")
        application.typeKey(.space, modifierFlags: [])
        assertReceipt(application.staticTexts["screen-url-picker.selection-receipt"], equals: "Selections: 1 — URL 2")
        application.terminate()

        application = launch(surface: "screen-urls", state: "normal")
        assertExists(application.descendants(matching: .any)["screen-url-picker"].firstMatch)
        application.typeText("0")
        XCTAssertEqual(
            application.staticTexts["screen-url-picker.selection-receipt"].value as? String,
            "Selections: 0 — No selection"
        )
        XCTAssertEqual(
            application.descendants(matching: .any)["screen-url-picker.open-all"].value as? String,
            "Selected"
        )
        application.typeKey(.return, modifierFlags: [])
        assertReceipt(
            application.staticTexts["screen-url-picker.selection-receipt"],
            equals: "Selections: 1 — Open all"
        )
        application.typeKey(.return, modifierFlags: [])
        assertReceipt(
            application.staticTexts["screen-url-picker.selection-receipt"],
            equals: "Selections: 1 — Open all"
        )
        application.typeKey(.escape, modifierFlags: [])
        application.typeKey(.escape, modifierFlags: [])
        assertReceipt(application.staticTexts["screen-url-picker.cancellation-receipt"], equals: "Cancellations: 1")
        application.terminate()
    }

    @MainActor
    func testScreenURLPickerKeyboardSelectionWinsUntilPointerMoves() {
        let application = launch(surface: "screen-urls", state: "many-urls")
        defer { application.terminate() }
        let firstRow = application.descendants(matching: .any)["screen-url-picker.row.0"]
        let scroll = application.scrollViews.firstMatch
        assertExists(firstRow)
        assertExists(scroll)
        makeHittable(firstRow, in: scroll, scrolling: .down)
        application.staticTexts["URLs Found on Screen"].hover()
        firstRow.hover()
        assertSelected(firstRow)

        for index in 1 ... 8 {
            application.typeKey(.downArrow, modifierFlags: [])
            assertSelected(application.descendants(matching: .any)["screen-url-picker.row.\(index)"])
        }

        let ninthRow = application.descendants(matching: .any)["screen-url-picker.row.8"]
        assertExists(ninthRow)
        XCTAssertTrue(ninthRow.isHittable)
        assertSelected(ninthRow)
        assertRemainsSelected(ninthRow)

        let movedPointerTarget = application.descendants(matching: .any)["screen-url-picker.open-all"]
        assertExists(movedPointerTarget)
        XCTAssertTrue(movedPointerTarget.isHittable)
        movedPointerTarget.hover()
        assertSelected(movedPointerTarget)
        XCTAssertFalse(ninthRow.isSelected)
    }

    // swiftlint:disable function_body_length
    @MainActor
    func testClipboardURLShortcutSettings() {
        let preferencesSuite = "KatabroUITests.clipboard-shortcut.\(UUID().uuidString)"
        var application = launch(
            surface: "settings",
            state: "normal",
            appearance: "light",
            preferencesSuite: preferencesSuite,
            resetsPreferences: true
        )
        defer { application.terminate() }
        var form = application.scrollViews["settings.general.form"]
        assertExists(form)
        var toggle = application.descendants(matching: .any)[
            "settings.clipboard-url.shortcut-toggle"
        ].firstMatch
        var recorder = application.descendants(matching: .any)[
            "settings.clipboard-url.shortcut-field"
        ].firstMatch
        assertExists(toggle)
        assertExists(recorder)
        XCTAssertFalse(isControlOn(toggle))
        XCTAssertEqual(shortcutValue(recorder), "⌃⌘B")
        toggle.click()
        XCTAssertTrue(isControlOn(toggle))
        var status = application.descendants(matching: .any)[
            "settings.clipboard-url.shortcut-status"
        ].firstMatch
        assertExists(status)
        XCTAssertEqual(status.value as? String, "Global shortcut is registered.")

        let screenToggle = application.descendants(matching: .any)[
            "settings.screen-url-capture.shortcut-toggle"
        ].firstMatch
        for _ in 0 ..< 4 where !screenToggle.exists {
            form.swipeUp()
        }
        assertExists(screenToggle)
        makeHittable(screenToggle, in: form, scrolling: .up)
        screenToggle.click()
        XCTAssertTrue(isControlOn(screenToggle))

        makeHittable(recorder, in: form, scrolling: .down)
        recorder.click()
        XCTAssertEqual(shortcutValue(recorder), "Press keys")
        recorder.typeKey(.delete, modifierFlags: [])
        XCTAssertEqual(shortcutValue(recorder), "Press keys")
        recorder.typeKey("x", modifierFlags: [.control, .command])
        XCTAssertEqual(shortcutValue(recorder), "⌃⌘X")
        status = application.descendants(matching: .any)[
            "settings.clipboard-url.shortcut-status"
        ].firstMatch
        XCTAssertEqual(
            status.value as? String,
            "This shortcut is already in use by another app or Katabro command."
        )

        recorder.click()
        recorder.typeKey("b", modifierFlags: [.control, .command])
        XCTAssertEqual(shortcutValue(recorder), "⌃⌘B")
        XCTAssertEqual(status.value as? String, "Global shortcut is registered.")
        recorder.click()
        recorder.typeKey(.escape, modifierFlags: [])
        XCTAssertEqual(shortcutValue(recorder), "⌃⌘B")
        XCTAssertFalse(application.alerts.firstMatch.exists)
        attachScreenshot(named: "Settings-clipboard-shortcut-enabled", from: application)

        application.terminate()
        application = launch(
            surface: "settings",
            state: "normal",
            appearance: "dark",
            preferencesSuite: preferencesSuite
        )
        form = application.scrollViews["settings.general.form"]
        toggle = application.descendants(matching: .any)[
            "settings.clipboard-url.shortcut-toggle"
        ].firstMatch
        recorder = application.descendants(matching: .any)[
            "settings.clipboard-url.shortcut-field"
        ].firstMatch
        assertExists(form)
        assertExists(toggle)
        assertExists(recorder)
        XCTAssertTrue(isControlOn(toggle))
        XCTAssertEqual(shortcutValue(recorder), "⌃⌘B")
        attachScreenshot(named: "Settings-clipboard-shortcut-persisted-dark", from: application)
    }

    // swiftlint:enable function_body_length

    @MainActor
    func testScreenURLSettings() {
        let preferencesSuite = "KatabroUITests.screen-url-capture.\(UUID().uuidString)"
        var application = launch(
            surface: "settings",
            state: "normal",
            appearance: "light",
            preferencesSuite: preferencesSuite,
            resetsPreferences: true
        )
        defer { application.terminate() }
        let form = application.scrollViews["settings.general.form"]
        assertExists(form)
        let captureToggle = application.descendants(matching: .any)[
            "settings.screen-url-capture.toggle"
        ].firstMatch
        let toggle = application.descendants(matching: .any)["settings.screen-url-capture.shortcut-toggle"].firstMatch
        for _ in 0 ..< 4 where !captureToggle.exists || !toggle.exists {
            form.swipeUp()
        }
        assertExists(captureToggle)
        XCTAssertTrue(isControlOn(captureToggle))
        assertExists(toggle)
        makeHittable(toggle, in: form, scrolling: .up)
        XCTAssertFalse(isControlOn(toggle))
        toggle.click()
        XCTAssertTrue(isControlOn(toggle))
        let status = application.descendants(matching: .any)["settings.screen-url-capture.shortcut-status"]
        assertExists(status)
        XCTAssertEqual(status.value as? String, "Global shortcut is registered.")
        let recorder = application.descendants(matching: .any)["settings.screen-url-capture.shortcut-field"]
        assertExists(recorder)
        recorder.click()
        XCTAssertEqual(shortcutValue(recorder), "Press keys")
        attachScreenshot(named: "Settings-screen-URL-shortcut-recording", from: application)
        recorder.typeKey(.delete, modifierFlags: [])
        XCTAssertEqual(shortcutValue(recorder), "Press keys")
        recorder.typeKey("x", modifierFlags: [.control, .command])
        XCTAssertEqual(shortcutValue(recorder), "⌃⌘X")
        recorder.click()
        recorder.typeKey("c", modifierFlags: [.command, .option])
        XCTAssertEqual(shortcutValue(recorder), "⌥⌘C")
        recorder.click()
        XCTAssertEqual(shortcutValue(recorder), "Press keys")
        recorder.typeKey(.escape, modifierFlags: [])
        XCTAssertEqual(shortcutValue(recorder), "⌥⌘C")
        XCTAssertEqual(status.value as? String, "Global shortcut is registered.")
        XCTAssertFalse(application.alerts.firstMatch.exists)
        attachScreenshot(named: "Settings-screen-URL-shortcut-enabled", from: application)
        verifyCaptureFeatureSwitch(
            in: &application,
            preferencesSuite: preferencesSuite
        )
        verifyCapturePermissionAndAvailabilityStates(in: &application)
    }

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
        let pickerTab = application.radioButtons["settings.pane.picker"]
        let rulesTab = application.radioButtons["settings.pane.rules"]
        let aboutTab = application.radioButtons["settings.pane.about"]

        assertExists(application.scrollViews["settings.general.form"])
        assertExists(generalTab)
        assertExists(browsersTab)
        assertExists(pickerTab)
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
            application.staticTexts["settings.default-browser.active"]
        )
        assertDoesNotExist(
            application.buttons["settings.default-browser.action"]
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
    func testMenuSettingsBringsSettingsForward() {
        let application = launch(
            surface: "menu",
            state: "normal"
        )
        defer {
            application.terminate()
        }

        let reviewWindow = application.windows["Katabro UI Review — Menu"]
        let settingsMenuItem = application.buttons["menu.settings"]
        assertExists(reviewWindow)
        assertExists(settingsMenuItem)

        settingsMenuItem.click()

        let settingsForm = application.scrollViews["settings.general.form"]
        assertExists(settingsForm)
        XCTAssertTrue(settingsForm.isHittable)
        settingsForm.click()
        XCTAssertTrue(settingsForm.isHittable)

        application.typeKey(",", modifierFlags: [.command])
        XCTAssertEqual(
            application.scrollViews.matching(
                identifier: "settings.general.form"
            ).count,
            1
        )
        XCTAssertTrue(settingsForm.isHittable)
        attachScreenshot(
            named: "Menu-settings-foreground-system",
            from: application
        )
    }

    // swiftlint:disable function_body_length
    @MainActor
    func testMenuReadyState() {
        let application = launch(
            surface: "menu",
            state: "normal"
        )
        defer {
            application.terminate()
        }

        assertExists(
            application.buttons["menu.open-url-from-clipboard"]
        )
        XCTAssertEqual(
            application.buttons["menu.open-url-from-clipboard"].value as? String,
            "⌃⌘B"
        )
        let clipboardPreview = application.staticTexts["menu.clipboard-url-preview"]
        assertExists(clipboardPreview)
        XCTAssertEqual(
            clipboardPreview.value as? String,
            "https://example.com"
        )
        assertDoesNotExist(
            application.buttons["menu.setup-required"]
        )
        assertExists(
            application.buttons["menu.settings"]
        )
        let capture = application.buttons["menu.capture-screen-urls"]
        assertExists(capture)
        XCTAssertEqual(capture.value as? String, "⌃⌘X")

        let statusItem = application.statusItems.firstMatch
        assertExists(statusItem)
        statusItem.click()
        let statusMenu = statusItem.menus.firstMatch
        assertExists(statusMenu)
        let statusCapture = statusMenu.descendants(matching: .any)["Capture URLs from Screen"]
        let statusClipboard = statusMenu.descendants(matching: .any)["Open URL from Clipboard"]
        assertExists(statusClipboard)
        assertExists(statusCapture)
        // XCTest exposes native menu items, but not their shortcut-column glyph values.
        // The attached screenshot and manual visual review own that platform assertion.
        attachScreenshot(named: "Menu-ready-shortcut-enabled", from: application)
        application.typeKey(.escape, modifierFlags: [])

        assertExists(
            application.descendants(matching: .any)["menu.more"]
        )
        assertDoesNotExist(
            application.descendants(matching: .any)["menu.default-browser-status"]
        )
        attachScreenshot(
            named: "Menu-ready",
            from: application
        )
        application.descendants(matching: .any)["menu.more"].click()
        assertExists(
            application.descendants(matching: .any)["menu.setup-guide"]
        )
        assertExists(
            application.descendants(matching: .any)["menu.rules"]
        )
        assertExists(
            application.descendants(matching: .any)["menu.about"]
        )
        application.descendants(matching: .any)["menu.rules"].click()
        assertExists(
            application.scrollViews["settings.rules.form"]
        )
    }

    // swiftlint:enable function_body_length

    @MainActor
    func testMenuSourceActionsLightAndDark() {
        for appearance in ["light", "dark"] {
            let application = launch(
                surface: "menu",
                state: "normal",
                appearance: appearance
            )
            assertExists(application.buttons["menu.open-url-from-clipboard"])
            assertExists(application.buttons["menu.capture-screen-urls"])
            attachScreenshot(named: "Menu-source-actions-\(appearance)", from: application)
            application.terminate()
        }
    }

    @MainActor
    func testMenuCapturePresentsFirstWindow() {
        let application = launch(surface: "menu", state: "normal")
        defer { application.terminate() }

        let reviewWindow = application.windows["Katabro UI Review — Menu"]
        assertExists(reviewWindow)
        application.typeKey("w", modifierFlags: [.command])
        assertDoesNotExist(reviewWindow)

        XCUIApplication(bundleIdentifier: "com.apple.finder").activate()

        let statusItem = application.statusItems.firstMatch
        assertExists(statusItem)
        statusItem.click()
        let statusCapture = statusItem.menus.firstMatch.descendants(matching: .any)[
            "Capture URLs from Screen"
        ]
        assertExists(statusCapture)
        statusCapture.click()

        let screenURLPicker = application.descendants(matching: .any)["screen-url-picker"].firstMatch
        assertExists(screenURLPicker)
        XCTAssertTrue(screenURLPicker.isHittable)
        for index in 0 ..< 3 {
            assertExists(
                application.descendants(matching: .any)[
                    "screen-url-picker.row.\(index)"
                ]
            )
        }
        attachScreenshot(named: "Menu-capture-first-window", from: application)
        application.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testMenuClipboardAction() {
        let application = launch(
            surface: "menu",
            state: "normal"
        )
        defer {
            application.terminate()
        }

        let clipboardAction = application.buttons["menu.open-url-from-clipboard"]
        assertExists(clipboardAction)
        XCTAssertTrue(clipboardAction.isEnabled)
        clipboardAction.click()

        let picker = application.descendants(matching: .any)["picker.content"]
        let destination = application.descendants(matching: .any)["picker.destination"]
        assertExists(picker)
        assertExists(destination)
        XCTAssertEqual(destination.value as? String, "https://example.com")

        application.typeKey(.escape, modifierFlags: [])
        assertDoesNotExist(picker)
    }

    @MainActor
    func testMenuLongClipboardURLPreview() {
        let application = launch(
            surface: "menu",
            state: "many-browsers"
        )
        defer {
            application.terminate()
        }

        let clipboardPreview = application.staticTexts["menu.clipboard-url-preview"]
        assertExists(clipboardPreview)
        XCTAssertEqual(
            clipboardPreview.value as? String,
            "https://documentation.preview.long-subdomain.example.com/guides/browser-routing?source=clipboard-fixture"
        )
        attachScreenshot(
            named: "Menu-long-clipboard-preview",
            from: application
        )
    }

    @MainActor
    func testStatusItemMenuUsesClipboardSnapshot() {
        let application = launch(
            surface: "menu",
            state: "many-browsers"
        )
        defer {
            application.terminate()
        }

        let statusItem = application.statusItems.firstMatch
        assertExists(statusItem)
        statusItem.click()

        let statusMenu = statusItem.menus.firstMatch
        assertExists(statusMenu)
        let clipboardAction = statusMenu.descendants(
            matching: .any
        )["Open URL from Clipboard"]
        let clipboardPreview = statusMenu.descendants(
            matching: .any
        )["https://documentation.previ…ing?source=clipboard-fixture"]
        assertExists(clipboardAction)
        assertExists(clipboardPreview)
        XCTAssertFalse(clipboardPreview.isEnabled)

        clipboardAction.click()

        let destination = application.descendants(matching: .any)["picker.destination"]
        assertExists(destination)
        XCTAssertEqual(
            destination.value as? String,
            "https://documentation.preview.long-subdomain.example.com/guides/browser-routing?source=clipboard-fixture"
        )
    }

    @MainActor
    func testMenuSetupRequiredState() {
        let application = launch(
            surface: "menu",
            state: "service-errors"
        )
        defer {
            application.terminate()
        }

        assertExists(
            application.buttons["menu.setup-required"]
        )
        assertDoesNotExist(
            application.buttons["menu.open-url-from-clipboard"]
        )
        assertExists(
            application.buttons["menu.settings"]
        )
        attachScreenshot(
            named: "Menu-setup-required",
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
            application.buttons["settings.default-browser.action"]
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
        attachScreenshot(
            named: "Settings-service-errors",
            from: application
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
        let pickerTab = application.radioButtons["settings.pane.picker"]
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
        pickerTab.click()
        assertExists(application.scrollViews["settings.picker.form"])
        assertExists(application.descendants(matching: .any)["settings.picker.orientation"])
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
    func testOnboardingNormalReviewSurface() {
        let application = launch(
            surface: "onboarding",
            state: "normal"
        )
        defer {
            application.terminate()
        }

        assertOnboardingExplanation(application)
        assertExists(
            application.staticTexts["onboarding.default-browser.status"]
        )
        assertDoesNotExist(
            application.buttons["onboarding.default-browser.action"]
        )
        assertExists(
            application.buttons["onboarding.done"]
        )
        attachScreenshot(
            named: "Onboarding-normal",
            from: application
        )
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

        assertOnboardingExplanation(application)
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

    @MainActor
    private func assertOnboardingExplanation(
        _ application: XCUIApplication
    ) {
        for paragraph in [
            "Katabro becomes your system default browser so it can receive web links.",
            "Choose where links open, or remember a browser for a specific website.",
        ] {
            assertExists(application.staticTexts[paragraph])
        }

        for oldTitle in [
            "Make Katabro your default browser",
            "Open any web link",
            "Choose with the mouse or keyboard",
        ] {
            assertDoesNotExist(application.staticTexts[oldTitle])
        }
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
                (destination.value as? String)?.contains("/fixture/index.html") == true
                    || destination.label.contains("/fixture/index.html")
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
    func testRecentRoutesStates() { // swiftlint:disable:this function_body_length
        var application = launch(
            surface: "settings",
            state: "recent-routes-empty",
            appearance: "light"
        )
        let emptyState = application.descendants(matching: .any)[
            "settings.recent-routes.empty"
        ]
        let privacyNotice = application.descendants(matching: .any)[
            "settings.recent-routes.privacy"
        ]

        assertExists(application.scrollViews["settings.rules.form"])
        assertExists(emptyState)
        assertExists(privacyNotice)
        XCTAssertEqual(emptyState.value as? String, "No recent routes yet.")
        attachScreenshot(
            named: "Settings-recent-routes-empty-light",
            from: application
        )
        application.terminate()

        let newestIDs = [
            "00000000-0000-0000-0000-000000000206",
            "00000000-0000-0000-0000-000000000205",
            "00000000-0000-0000-0000-000000000204",
        ]
        let retainedIDs = newestIDs + [
            "00000000-0000-0000-0000-000000000203",
            "00000000-0000-0000-0000-000000000202",
            "00000000-0000-0000-0000-000000000201",
        ]

        for appearance in ["light", "dark"] {
            application = launch(
                surface: "settings",
                state: "recent-routes",
                appearance: appearance
            )
            let form = application.scrollViews["settings.rules.form"]
            assertExists(form)
            XCTAssertTrue(
                isControlOn(application.radioButtons["settings.pane.rules"])
            )

            for requestID in newestIDs {
                assertExists(
                    application.descendants(matching: .any)[
                        "settings.recent-routes.preview-row.\(requestID)"
                    ]
                )
            }
            assertDoesNotExist(
                application.descendants(matching: .any)[
                    "settings.recent-routes.preview-row.00000000-0000-0000-0000-000000000203"
                ]
            )
            assertExists(
                application.descendants(matching: .any)[
                    "settings.rule.exact.example.com"
                ]
            )
            assertExists(
                application.descendants(matching: .any)[
                    "settings.rule.replace.example.com"
                ]
            )
            let exactRuleRemove = application.descendants(matching: .any)[
                "settings.rule.exact.example.com.remove"
            ]
            let replaceRuleRemove = application.descendants(matching: .any)[
                "settings.rule.replace.example.com.remove"
            ]
            assertExists(exactRuleRemove)
            assertExists(replaceRuleRemove)
            application.activate()
            XCTAssertTrue(exactRuleRemove.isHittable)
            XCTAssertTrue(replaceRuleRemove.isHittable)
            assertExists(
                application.descendants(matching: .any)[
                    "settings.recent-routes.privacy"
                ]
            )
            assertExists(application.staticTexts["Couldn’t open target"])

            let reviewWindow = application.windows[
                "Katabro UI Review — Settings"
            ]
            assertExists(reviewWindow)
            XCTAssertEqual(reviewWindow.frame.width, 560, accuracy: 2)
            XCTAssertLessThanOrEqual(reviewWindow.frame.height, 620)

            for requestID in newestIDs {
                let row = application.descendants(matching: .any)[
                    "settings.recent-routes.preview-row.\(requestID)"
                ]
                XCTAssertFalse(row.debugDescription.contains("fixture/private-path"))
                XCTAssertFalse(row.debugDescription.contains("secret="))
                XCTAssertFalse(row.debugDescription.contains("#hidden"))
            }

            attachScreenshot(
                named: "Settings-recent-routes-collapsed-\(appearance)",
                from: application
            )

            let showAll = application.buttons[
                "settings.recent-routes.show-all"
            ]
            assertExists(showAll)
            showAll.click()

            for requestID in retainedIDs {
                assertExists(
                    application.descendants(matching: .any)[
                        "settings.recent-routes.expanded-row.\(requestID)"
                    ]
                )
            }
            let exactSuccess = application.descendants(matching: .any)[
                "settings.recent-routes.expanded-row.00000000-0000-0000-0000-000000000201"
            ]
            let normalPickerSuccess = application.descendants(matching: .any)[
                "settings.recent-routes.expanded-row.00000000-0000-0000-0000-000000000202"
            ]
            let unavailableFallback = application.descendants(matching: .any)[
                "settings.recent-routes.expanded-row.00000000-0000-0000-0000-000000000203"
            ]
            XCTAssertFalse(accessibilityCopy(in: exactSuccess).contains("com.example.browser"))
            XCTAssertFalse(accessibilityCopy(in: normalPickerSuccess).contains("com.example.create:profile:work"))
            XCTAssertFalse(accessibilityCopy(in: unavailableFallback).contains("com.example.replacement:private"))
            attachScreenshot(
                named: "Settings-recent-routes-expanded-\(appearance)",
                from: application
            )

            let showLess = application.buttons[
                "settings.recent-routes.show-less"
            ]
            makeHittable(showLess, in: form, scrolling: .up)
            showLess.click()
            for requestID in newestIDs {
                assertExists(
                    application.descendants(matching: .any)[
                        "settings.recent-routes.preview-row.\(requestID)"
                    ]
                )
            }
            assertDoesNotExist(
                application.descendants(matching: .any)[
                    "settings.recent-routes.expanded-row.00000000-0000-0000-0000-000000000203"
                ]
            )

            application.terminate()
        }

        application = launch(
            surface: "settings",
            state: "recent-routes",
            appearance: "light"
        )
        let clear = application.descendants(matching: .any)[
            "settings.recent-routes.clear"
        ]
        assertExists(clear)
        XCTAssertEqual(clear.elementType, .button)
        application.activate()
        XCTAssertTrue(clear.isHittable)
        clear.click()
        assertExists(
            application.descendants(matching: .any)[
                "settings.recent-routes.empty"
            ]
        )
        assertDoesNotExist(
            application.descendants(matching: .any)[
                "settings.recent-routes.preview-row.00000000-0000-0000-0000-000000000206"
            ]
        )
        attachScreenshot(
            named: "Settings-recent-routes-cleared-light",
            from: application
        )
        application.terminate()
    }

    @MainActor
    func testRecentRoutesCreateAndReplaceRule() { // swiftlint:disable:this function_body_length
        let application = launch(
            surface: "settings",
            state: "recent-routes",
            preferencesSuite: "recent-routes-rules-\(UUID().uuidString)",
            resetsPreferences: true
        )
        defer {
            application.terminate()
        }
        let form = application.scrollViews["settings.rules.form"]
        assertExists(form)
        XCTAssertTrue(
            isControlOn(application.radioButtons["settings.pane.rules"])
        )
        application.buttons["settings.recent-routes.show-all"].click()

        let createRule = application.buttons[
            "settings.recent-routes.rule-action.00000000-0000-0000-0000-000000000202"
        ]
        makeHittable(createRule, in: form, scrolling: .up)
        createRule.click()
        let confirmCreate = dialogButton(
            application,
            identifier: "settings.recent-routes.rule-confirm",
            label: "Create Rule"
        )
        assertExists(confirmCreate)
        confirmCreate.click()

        assertExists(
            application.descendants(matching: .any)[
                "settings.recent-routes.rule-exists.00000000-0000-0000-0000-000000000202"
            ]
        )
        assertExists(
            application.descendants(matching: .any)[
                "settings.rule.create.example.com"
            ]
        )
        assertExists(application.staticTexts["com.example.create:profile:work"])

        let replaceRule = application.buttons[
            "settings.recent-routes.rule-action.00000000-0000-0000-0000-000000000203"
        ]
        makeHittable(replaceRule, in: form, scrolling: .down)
        replaceRule.click()
        let cancelReplace = dialogButton(
            application,
            identifier: "settings.recent-routes.rule-cancel",
            label: "Cancel"
        )
        assertExists(cancelReplace)
        cancelReplace.click()
        assertExists(application.staticTexts["com.example.previous"])
        assertDoesNotExist(
            application.staticTexts["com.example.replacement:private"]
        )

        let replaceAfterCancellation = application.buttons[
            "settings.recent-routes.rule-action.00000000-0000-0000-0000-000000000203"
        ]
        makeHittable(replaceAfterCancellation, in: form, scrolling: .down)
        replaceAfterCancellation.click()
        let confirmReplace = dialogButton(
            application,
            identifier: "settings.recent-routes.rule-confirm",
            label: "Replace Rule"
        )
        assertExists(confirmReplace)
        confirmReplace.click()

        assertExists(application.staticTexts["com.example.replacement:private"])
        assertDoesNotExist(application.staticTexts["com.example.previous"])
        assertExists(form)
        XCTAssertTrue(
            isControlOn(application.radioButtons["settings.pane.rules"])
        )
        assertDoesNotExist(
            application.descendants(matching: .any)["picker.content"]
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
                let picker = application.descendants(matching: .any)["picker.content"]
                assertExists(picker)
                XCTAssertEqual(picker.frame.width, 320, accuracy: 1)
                XCTAssertLessThanOrEqual(picker.frame.height, state == "normal" ? 280 : 320)
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
    func testPickerCopyLink() { // swiftlint:disable:this function_body_length
        let preferencesSuite = "picker-copy-link-\(UUID().uuidString)"
        var application = launch(
            surface: "picker",
            state: "normal",
            preferencesSuite: preferencesSuite,
            resetsPreferences: true
        )
        var copyReceipt = application.descendants(matching: .any)["picker.copy-receipt"]
        var selectionReceipt = application.descendants(matching: .any)["picker.selection-receipt"]
        var cancellationReceipt = application.descendants(matching: .any)["picker.cancellation-receipt"]
        let destination = application.descendants(matching: .any)["picker.destination"]
        assertExists(copyReceipt)
        assertExists(selectionReceipt)
        assertExists(cancellationReceipt)
        assertExists(destination)

        application.typeKey("c", modifierFlags: [.command])
        assertReceipt(copyReceipt, equals: "Link copied 1 time")
        XCTAssertEqual(selectionReceipt.value as? String, "No browser selected")
        XCTAssertEqual(cancellationReceipt.value as? String, "Picker not cancelled")

        application.typeKey("c", modifierFlags: [])
        assertReceipt(selectionReceipt, equals: "Google Chrome selected 1 time")
        XCTAssertEqual(copyReceipt.value as? String, "Link copied 1 time")
        for modifiers in [
            XCUIElement.KeyModifierFlags.option,
            XCUIElement.KeyModifierFlags.control,
        ] {
            application.typeKey("c", modifierFlags: modifiers)
        }
        XCTAssertEqual(selectionReceipt.value as? String, "Google Chrome selected 1 time")
        XCTAssertEqual(copyReceipt.value as? String, "Link copied 1 time")

        destination.rightClick()
        let copyLink = application.descendants(matching: .any)["picker.copy-link"]
        assertExists(copyLink)
        copyLink.click()
        assertReceipt(copyReceipt, equals: "Link copied 2 times")
        XCTAssertEqual(selectionReceipt.value as? String, "Google Chrome selected 1 time")
        XCTAssertEqual(cancellationReceipt.value as? String, "Picker not cancelled")
        application.terminate()

        application = launch(
            surface: "settings",
            state: "normal",
            preferencesSuite: preferencesSuite
        )
        openPickerSettings(in: application)
        selectPickerMenu("Hidden", identifier: "settings.picker.destination", in: application)
        application.terminate()

        application = launch(
            surface: "picker",
            state: "normal",
            preferencesSuite: preferencesSuite
        )
        copyReceipt = application.descendants(matching: .any)["picker.copy-receipt"]
        selectionReceipt = application.descendants(matching: .any)["picker.selection-receipt"]
        cancellationReceipt = application.descendants(matching: .any)["picker.cancellation-receipt"]
        assertExists(copyReceipt)
        XCTAssertFalse(application.descendants(matching: .any)["picker.destination"].exists)

        application.typeKey("c", modifierFlags: [.command])
        assertReceipt(copyReceipt, equals: "Link copied 1 time")
        XCTAssertEqual(selectionReceipt.value as? String, "No browser selected")
        XCTAssertEqual(cancellationReceipt.value as? String, "Picker not cancelled")
        application.terminate()
    }

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
    func testManyBrowserPickerKeyboardSelectionScrollsToLateRows() {
        let application = launch(
            surface: "picker",
            state: "many-browsers",
            preferencesSuite: "vertical-many-\(UUID().uuidString)",
            resetsPreferences: true
        )
        defer { application.terminate() }
        let picker = application.descendants(matching: .any)["picker.content"]
        let scrollArea = application.descendants(matching: .any)["picker.scroll-area"]
        let destination = application.descendants(matching: .any)["picker.destination"]
        let remember = application.descendants(matching: .any)["picker.remember-host"]
        let lateTarget = application.descendants(matching: .any)[
            "picker.browser.com.duckduckgo.macos.browser"
        ]
        let firstTarget = application.descendants(matching: .any)[
            "picker.browser.com.apple.Safari"
        ]
        let receipt = application.descendants(matching: .any)["picker.selection-receipt"]
        let fullURL = "https://documentation.preview.long-subdomain.example.com/guides/browser-routing?source=fixture"

        assertExists(picker)
        assertExists(scrollArea)
        XCTAssertEqual(application.scrollBars.count, 0)
        assertExists(destination)
        assertExists(remember)
        XCTAssertEqual(picker.frame.width, 320, accuracy: 1)
        XCTAssertLessThanOrEqual(picker.frame.height, 320)
        XCTAssertTrue(destination.label.contains("documentation.preview.long-subdomain.example.com"))
        XCTAssertEqual(destination.value as? String, fullURL)
        XCTAssertEqual(remember.label, "Remember for documentation.preview.long-subdomain.example.com")
        XCTAssertTrue(firstTarget.isSelected)
        application.activate()
        XCTAssertTrue(firstTarget.isHittable)
        XCTAssertLessThanOrEqual(firstTarget.frame.minY, scrollArea.frame.minY + 2)
        for _ in 0 ..< 10 {
            application.typeKey(.downArrow, modifierFlags: [])
        }
        assertExists(lateTarget)
        XCTAssertTrue(lateTarget.isSelected)
        application.activate()
        XCTAssertTrue(lateTarget.isHittable)
        application.typeKey(.return, modifierFlags: [])
        assertReceipt(receipt, equals: "DuckDuckGo Privacy Browser — Long Name Fixture selected 1 time")
        application.typeKey(.downArrow, modifierFlags: [])
        application.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(firstTarget.isSelected)
        application.activate()
        XCTAssertTrue(firstTarget.isHittable)
        XCTAssertEqual(receipt.value as? String, "DuckDuckGo Privacy Browser — Long Name Fixture selected 1 time")
    }

    @MainActor
    func testHorizontalManyBrowserPickerKeyboardSelectionScrollsToLateTargets() {
        let suite = "horizontal-many-\(UUID().uuidString)"
        configureHorizontalPicker(preferencesSuite: suite)
        let application = launch(surface: "picker", state: "many-browsers", preferencesSuite: suite)
        defer { application.terminate() }
        let picker = application.descendants(matching: .any)["picker.content"]
        let scrollArea = application.descendants(matching: .any)["picker.scroll-area"]
        let firstTarget = application.descendants(matching: .any)["picker.browser.com.apple.Safari"]
        let orion = application.descendants(matching: .any)["picker.browser.com.kagi.kagimacOS"]
        let lateTarget = application.descendants(matching: .any)[
            "picker.browser.com.duckduckgo.macos.browser"
        ]
        let receipt = application.descendants(matching: .any)["picker.selection-receipt"]

        assertExists(picker)
        assertExists(scrollArea)
        XCTAssertEqual(application.scrollBars.count, 0)
        XCTAssertEqual(picker.frame.width, 316, accuracy: 1)
        XCTAssertLessThanOrEqual(picker.frame.height, 190)
        XCTAssertTrue(firstTarget.isSelected)
        XCTAssertLessThanOrEqual(firstTarget.frame.minX, scrollArea.frame.minX + 2)
        for _ in 0 ..< 10 {
            application.typeKey(.rightArrow, modifierFlags: [])
        }
        assertExists(lateTarget)
        XCTAssertTrue(lateTarget.isSelected)
        XCTAssertTrue(lateTarget.isHittable)
        application.typeKey(.return, modifierFlags: [])
        assertReceipt(receipt, equals: "DuckDuckGo Privacy Browser — Long Name Fixture selected 1 time")

        application.typeKey(.leftArrow, modifierFlags: [])
        XCTAssertTrue(orion.isSelected)
        application.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(lateTarget.isSelected)
        application.typeKey(.upArrow, modifierFlags: [])
        XCTAssertTrue(orion.isSelected)
        for _ in 0 ..< 3 {
            application.typeKey(.rightArrow, modifierFlags: [])
        }
        XCTAssertTrue(firstTarget.isSelected)
        XCTAssertTrue(firstTarget.isHittable)
        XCTAssertEqual(receipt.value as? String, "DuckDuckGo Privacy Browser — Long Name Fixture selected 1 time")
    }

    @MainActor
    func testPickerKeyboardSelectionWinsUntilPointerMoves() {
        let suite = "hover-arbitration-\(UUID().uuidString)"
        let application = launch(
            surface: "picker",
            state: "many-browsers",
            preferencesSuite: suite,
            resetsPreferences: true
        )
        defer { application.terminate() }
        let firstTarget = application.descendants(matching: .any)["picker.browser.com.apple.Safari"]
        let lateTarget = application.descendants(matching: .any)[
            "picker.browser.com.duckduckgo.macos.browser"
        ]
        assertExists(firstTarget)
        firstTarget.hover()
        XCTAssertTrue(firstTarget.isSelected)

        let navigationTargets = [
            "picker.browser.com.google.Chrome",
            "picker.browser.org.mozilla.firefox",
            "picker.browser.company.thebrowser.Browser",
            "picker.browser.com.microsoft.edgemac",
            "picker.browser.com.brave.Browser",
            "picker.browser.com.operasoftware.Opera",
            "picker.browser.com.vivaldi.Vivaldi",
            "picker.browser.org.chromium.Chromium",
            "picker.browser.com.kagi.kagimacOS",
            "picker.browser.com.duckduckgo.macos.browser",
        ]
        for identifier in navigationTargets {
            application.typeKey(.downArrow, modifierFlags: [])
            let target = application.descendants(matching: .any)[identifier]
            assertSelected(target)
        }

        assertExists(lateTarget)
        XCTAssertTrue(lateTarget.isHittable)
        XCTAssertTrue(lateTarget.isSelected)

        let movedPointerTarget = application.descendants(matching: .any)["picker.browser.com.kagi.kagimacOS"]
        assertExists(movedPointerTarget)
        XCTAssertTrue(movedPointerTarget.isHittable)
        movedPointerTarget.hover()
        assertSelected(movedPointerTarget)
        XCTAssertFalse(lateTarget.isSelected)
    }

    @MainActor
    func testPickerSettingsPersistAndAffectPresentation() { // swiftlint:disable:this function_body_length
        let suite = "picker-presentation-\(UUID().uuidString)"
        var application = launch(
            surface: "settings",
            state: "normal",
            preferencesSuite: suite,
            resetsPreferences: true
        )
        openPickerSettings(in: application)
        let horizontalLabels = application.popUpButtons["settings.picker.horizontal-labels"]
        XCTAssertFalse(horizontalLabels.isEnabled)
        application.radioButtons["Horizontal"].click()
        XCTAssertTrue(horizontalLabels.isEnabled)
        setVisibleChoices(3, in: application)
        selectPickerMenu("Full URL", identifier: "settings.picker.destination", in: application)
        selectPickerMenu("Hidden", identifier: "settings.picker.shortcut-hints", in: application)
        selectPickerMenu("All", identifier: "settings.picker.horizontal-labels", in: application)
        let rememberToggle = application.switches["settings.picker.show-remember"]
        assertExists(rememberToggle)
        rememberToggle.click()
        application.terminate()

        application = launch(surface: "settings", state: "normal", preferencesSuite: suite)
        openPickerSettings(in: application)
        XCTAssertTrue(isControlOn(application.radioButtons["Horizontal"]))
        XCTAssertEqual(integerValue(application.steppers["settings.picker.visible-choices"]), 3)
        XCTAssertEqual(application.popUpButtons["settings.picker.destination"].value as? String, "Full URL")
        XCTAssertEqual(application.popUpButtons["settings.picker.shortcut-hints"].value as? String, "Hidden")
        XCTAssertEqual(application.popUpButtons["settings.picker.horizontal-labels"].value as? String, "All")
        XCTAssertFalse(isControlOn(application.switches["settings.picker.show-remember"]))
        application.terminate()

        application = launch(surface: "picker", state: "many-browsers", preferencesSuite: suite)
        let safari = application.descendants(matching: .any)["picker.browser.com.apple.Safari"]
        let chrome = application.descendants(matching: .any)["picker.browser.com.google.Chrome"]
        let picker = application.descendants(matching: .any)["picker.content"]
        let destination = application.descendants(matching: .any)["picker.destination"]
        let receipt = application.descendants(matching: .any)["picker.selection-receipt"]
        assertExists(safari)
        assertExists(chrome)
        assertExists(picker)
        XCTAssertLessThan(abs(safari.frame.midY - chrome.frame.midY), 5)
        XCTAssertEqual(picker.frame.width, 196, accuracy: 1)
        XCTAssertEqual(picker.value as? String, "Horizontal, 3 visible choices")
        XCTAssertEqual(safari.value as? String, "Shortcut hints: Hidden, Horizontal labels: All")
        XCTAssertEqual(
            destination.label,
            "Destination https://documentation.preview.long-subdomain.example.com/guides/browser-routing?source=fixture"
        )
        let allLabelsCellWidth = safari.frame.width
        XCTAssertFalse(application.descendants(matching: .any)["picker.remember-host"].exists)
        application.typeKey("r", modifierFlags: [.command, .shift])
        XCTAssertEqual(receipt.value as? String, "No browser selected")
        application.typeKey("s", modifierFlags: [])
        assertReceipt(receipt, equals: "Safari selected 1 time")
        application.typeKey("2", modifierFlags: [])
        assertReceipt(receipt, equals: "Google Chrome selected 2 times")
        application.terminate()

        application = launch(surface: "settings", state: "normal", preferencesSuite: suite)
        openPickerSettings(in: application)
        selectPickerMenu("Hidden", identifier: "settings.picker.destination", in: application)
        selectPickerMenu("Letters", identifier: "settings.picker.shortcut-hints", in: application)
        selectPickerMenu("Selected Only", identifier: "settings.picker.horizontal-labels", in: application)
        application.switches["settings.picker.show-remember"].click()
        application.terminate()

        application = launch(surface: "picker", state: "many-browsers", preferencesSuite: suite)
        let selectedOnlySafari = application.descendants(matching: .any)["picker.browser.com.apple.Safari"]
        XCTAssertFalse(application.descendants(matching: .any)["picker.destination"].exists)
        assertExists(application.descendants(matching: .any)["picker.remember-host"])
        XCTAssertEqual(selectedOnlySafari.value as? String, "Shortcut hints: Letters, Horizontal labels: Selected Only")
        XCTAssertEqual(selectedOnlySafari.frame.width, allLabelsCellWidth, accuracy: 1)
        application.terminate()

        application = launch(surface: "settings", state: "normal", preferencesSuite: suite)
        openPickerSettings(in: application)
        selectPickerMenu("Domain", identifier: "settings.picker.destination", in: application)
        selectPickerMenu("Numbers", identifier: "settings.picker.shortcut-hints", in: application)
        application.terminate()

        application = launch(surface: "picker", state: "many-browsers", preferencesSuite: suite)
        let numbersSafari = application.descendants(matching: .any)["picker.browser.com.apple.Safari"]
        let domain = application.descendants(matching: .any)["picker.destination"]
        let numbersReceipt = application.descendants(matching: .any)["picker.selection-receipt"]
        XCTAssertTrue(domain.label.contains("documentation.preview.long-subdomain.example.com"))
        XCTAssertEqual(
            domain.value as? String,
            "https://documentation.preview.long-subdomain.example.com/guides/browser-routing?source=fixture"
        )
        XCTAssertEqual(numbersSafari.value as? String, "Shortcut hints: Numbers, Horizontal labels: Selected Only")
        application.typeKey("s", modifierFlags: [])
        assertReceipt(numbersReceipt, equals: "Safari selected 1 time")
        application.terminate()

        application = launch(surface: "settings", state: "normal", preferencesSuite: suite)
        openPickerSettings(in: application)
        selectPickerMenu("All", identifier: "settings.picker.shortcut-hints", in: application)
        application.terminate()

        application = launch(surface: "picker", state: "normal", preferencesSuite: suite)
        defer { application.terminate() }
        let allSafari = application.descendants(matching: .any)["picker.browser.com.apple.Safari"]
        XCTAssertEqual(allSafari.value as? String, "Shortcut hints: All, Horizontal labels: Selected Only")
        application.typeKey("2", modifierFlags: [])
        assertReceipt(
            application.descendants(matching: .any)["picker.selection-receipt"],
            equals: "Google Chrome selected 1 time"
        )
    }

    @MainActor
    func testPickerSettingsPreview() { // swiftlint:disable:this function_body_length
        let application = launch(
            surface: "settings",
            state: "normal",
            preferencesSuite: "picker-preview-\(UUID().uuidString)",
            resetsPreferences: true
        )
        defer { application.terminate() }

        openPickerSettings(in: application)
        let hiddenNote = application.staticTexts[
            "settings.picker.shortcut-hints-hidden-note"
        ]
        let previewButton = application.buttons["settings.picker.preview"]
        XCTAssertFalse(hiddenNote.exists)
        assertExists(previewButton)

        let verticalWidth = application.popUpButtons["settings.picker.vertical-width"]
        assertExists(verticalWidth)
        XCTAssertTrue(verticalWidth.isEnabled)
        XCTAssertEqual(verticalWidth.value as? String, "Standard (320 pt)")

        previewButton.click()
        var picker = application.descendants(matching: .any)["picker.content"]
        assertExists(picker)
        XCTAssertEqual(picker.frame.width, 320, accuracy: 1)
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(picker.exists)

        selectPickerMenu(
            "Compact (280 pt)",
            identifier: "settings.picker.vertical-width",
            in: application
        )
        previewButton.click()
        picker = application.descendants(matching: .any)["picker.content"]
        assertExists(picker)
        XCTAssertEqual(picker.frame.width, 280, accuracy: 1)
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(picker.exists)

        application.radioButtons["Horizontal"].click()
        XCTAssertFalse(verticalWidth.isEnabled)
        XCTAssertEqual(verticalWidth.value as? String, "Compact (280 pt)")
        setVisibleChoices(3, in: application)
        selectPickerMenu(
            "Full URL",
            identifier: "settings.picker.destination",
            in: application
        )
        selectPickerMenu(
            "Hidden",
            identifier: "settings.picker.shortcut-hints",
            in: application
        )
        assertExists(hiddenNote)
        XCTAssertEqual(
            hiddenNote.value as? String,
            "Keyboard shortcuts remain active."
        )

        previewButton.click()
        picker = application.descendants(matching: .any)["picker.content"]
        let destination = application.descendants(matching: .any)["picker.destination"]
        assertExists(picker)
        XCTAssertEqual(picker.value as? String, "Horizontal, 3 visible choices")
        XCTAssertEqual(picker.frame.width, 196, accuracy: 1)
        XCTAssertEqual(destination.value as? String, "https://example.com")

        application.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(picker.exists)
        assertExists(previewButton)

        selectPickerMenu(
            "All",
            identifier: "settings.picker.shortcut-hints",
            in: application
        )
        XCTAssertFalse(hiddenNote.exists)

        previewButton.click()
        let safari = application.descendants(matching: .any)[
            "picker.browser.com.apple.Safari"
        ]
        assertExists(safari)
        safari.click()
        XCTAssertFalse(application.descendants(matching: .any)["picker.content"].exists)
        assertExists(previewButton)
    }

    @MainActor
    func testPickerVerticalWidthPersistsAndAffectsPresentation() {
        let suite = "picker-vertical-width-\(UUID().uuidString)"
        var application = launch(
            surface: "settings",
            state: "normal",
            preferencesSuite: suite,
            resetsPreferences: true
        )
        openPickerSettings(in: application)
        let width = application.popUpButtons["settings.picker.vertical-width"]
        assertExists(width)
        XCTAssertTrue(width.isEnabled)
        XCTAssertEqual(width.value as? String, "Standard (320 pt)")
        selectPickerMenu(
            "Compact (280 pt)",
            identifier: "settings.picker.vertical-width",
            in: application
        )
        application.radioButtons["Horizontal"].click()
        XCTAssertFalse(width.isEnabled)
        XCTAssertEqual(width.value as? String, "Compact (280 pt)")
        application.terminate()

        application = launch(surface: "settings", state: "normal", preferencesSuite: suite)
        openPickerSettings(in: application)
        let persistedWidth = application.popUpButtons["settings.picker.vertical-width"]
        XCTAssertFalse(persistedWidth.isEnabled)
        XCTAssertEqual(persistedWidth.value as? String, "Compact (280 pt)")
        application.radioButtons["Vertical"].click()
        XCTAssertTrue(persistedWidth.isEnabled)
        XCTAssertEqual(persistedWidth.value as? String, "Compact (280 pt)")
        application.terminate()

        application = launch(surface: "picker", state: "normal", preferencesSuite: suite)
        var picker = application.descendants(matching: .any)["picker.content"]
        assertExists(picker)
        XCTAssertEqual(picker.frame.width, 280, accuracy: 1)
        application.terminate()

        application = launch(surface: "settings", state: "normal", preferencesSuite: suite)
        openPickerSettings(in: application)
        selectPickerMenu(
            "Standard (320 pt)",
            identifier: "settings.picker.vertical-width",
            in: application
        )
        application.terminate()

        application = launch(surface: "picker", state: "normal", preferencesSuite: suite)
        defer { application.terminate() }
        picker = application.descendants(matching: .any)["picker.content"]
        assertExists(picker)
        XCTAssertEqual(picker.frame.width, 320, accuracy: 1)
    }

    @MainActor
    func testHorizontalPickerLightAndDarkScreenshots() {
        for appearance in ["light", "dark"] {
            let suite = "horizontal-screenshot-\(appearance)-\(UUID().uuidString)"
            configureHorizontalPicker(preferencesSuite: suite)
            for state in ["normal", "many-browsers"] {
                let application = launch(
                    surface: "picker",
                    state: state,
                    appearance: appearance,
                    preferencesSuite: suite
                )
                assertExists(application.descendants(matching: .any)["picker.scroll-area"])
                let picker = application.descendants(matching: .any)["picker.content"]
                assertExists(picker)
                XCTAssertEqual(picker.frame.width, state == "normal" ? 256 : 316, accuracy: 1)
                XCTAssertLessThanOrEqual(picker.frame.height, 190)
                attachScreenshot(named: "Picker-horizontal-\(state)-\(appearance)", from: application)
                application.terminate()
            }
        }
    }

    @MainActor
    func testPickerEmptyStateOmitsActionChrome() {
        let application = launch(surface: "picker", state: "no-browsers")
        defer { application.terminate() }
        assertExists(application.descendants(matching: .any)["picker.destination"])
        assertExists(application.descendants(matching: .any)["picker.empty-state"])
        XCTAssertFalse(application.descendants(matching: .any)["picker.scroll-area"].exists)
        XCTAssertFalse(application.descendants(matching: .any)["picker.remember-host"].exists)
        XCTAssertEqual(
            application.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'picker.browser.'")).count,
            0
        )
        application.typeKey("r", modifierFlags: [.command, .shift])
        application.typeKey(.return, modifierFlags: [])
        XCTAssertEqual(
            application.descendants(matching: .any)["picker.selection-receipt"].value as? String,
            "No browser selected"
        )
    }

    @MainActor
    func testPickerProfileAndPrivateIdentity() {
        let application = launch(surface: "picker", state: "browser-profiles")
        defer { application.terminate() }
        let privateTarget = application.descendants(matching: .any)[
            "picker.target.com.google.chrome:private"
        ]
        let profileTarget = application.descendants(matching: .any)[
            "picker.target.com.google.chrome:profile:Default"
        ]
        assertExists(privateTarget)
        assertExists(profileTarget)
        XCTAssertEqual(privateTarget.label, "Open in Private Window, Google Chrome")
        XCTAssertEqual(profileTarget.label, "Open in Personal, Google Chrome")
        XCTAssertFalse(application.images["person.crop.circle.fill"].exists)
        XCTAssertFalse(application.images["eye.slash.fill"].exists)
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
    func openPickerSettings(in application: XCUIApplication) {
        let pickerTab = application.radioButtons["settings.pane.picker"]
        assertExists(pickerTab)
        pickerTab.click()
        assertExists(application.scrollViews["settings.picker.form"])
    }

    @MainActor
    func setVisibleChoices(_ count: Int, in application: XCUIApplication) {
        let stepper = application.steppers["settings.picker.visible-choices"]
        assertExists(stepper)
        guard let current = integerValue(stepper) else {
            XCTFail("Visible choices did not expose an integer value")
            return
        }
        let delta = count - current
        let arrow = delta > 0 ? stepper.incrementArrows.firstMatch : stepper.decrementArrows.firstMatch
        assertExists(arrow)
        for _ in 0 ..< abs(delta) {
            arrow.click()
        }
        XCTAssertEqual(integerValue(stepper), count)
    }

    @MainActor
    func integerValue(_ element: XCUIElement) -> Int? {
        if let number = element.value as? NSNumber {
            return number.intValue
        }
        if let string = element.value as? String {
            return Int(string)
        }
        return nil
    }

    @MainActor
    func selectPickerMenu(
        _ value: String,
        identifier: String,
        in application: XCUIApplication
    ) {
        let picker = application.popUpButtons[identifier]
        assertExists(picker)
        picker.click()
        let item = application.menuItems[value]
        assertExists(item)
        item.click()
        XCTAssertEqual(picker.value as? String, value)
    }

    @MainActor
    func configureHorizontalPicker(preferencesSuite: String) {
        let application = launch(
            surface: "settings",
            state: "normal",
            preferencesSuite: preferencesSuite,
            resetsPreferences: true
        )
        openPickerSettings(in: application)
        application.radioButtons["Horizontal"].click()
        application.terminate()
    }

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
    func assertManyURLShortcutPresentation(in application: XCUIApplication, scroll: XCUIElement) {
        let ninthRow = application.descendants(matching: .any)["screen-url-picker.row.8"]
        let tenthRow = application.descendants(matching: .any)["screen-url-picker.row.9"]
        for _ in 0 ..< 3 where !tenthRow.exists {
            scroll.swipeUp()
        }
        assertExists(ninthRow)
        assertExists(tenthRow)
        let ninthShortcut = application.descendants(matching: .any)["screen-url-picker.shortcut.8"]
        assertExists(ninthShortcut)
        XCTAssertEqual(ninthShortcut.label, "Keyboard shortcut 9")
        XCTAssertEqual(ninthShortcut.frame.midY, ninthRow.frame.midY, accuracy: 1)
        assertDoesNotExist(application.descendants(matching: .any)["screen-url-picker.shortcut.9"])
    }

    @MainActor
    func verifyCaptureFeatureSwitch(
        in application: inout XCUIApplication,
        preferencesSuite: String
    ) {
        var form = application.scrollViews["settings.general.form"]
        var captureToggle = application.descendants(matching: .any)["settings.screen-url-capture.toggle"].firstMatch
        makeHittable(captureToggle, in: form, scrolling: .down)
        captureToggle.click()
        XCTAssertFalse(isControlOn(captureToggle))
        assertDoesNotExist(
            application.descendants(matching: .any)["settings.screen-url-capture.shortcut-toggle"]
        )
        assertDoesNotExist(
            application.descendants(matching: .any)["settings.screen-url-capture.shortcut-field"]
        )
        assertDoesNotExist(
            application.descendants(matching: .any)["settings.screen-url-capture.shortcut-status"]
        )
        assertDoesNotExist(
            application.descendants(matching: .any)["settings.screen-url-capture.permission-authorized-status"]
        )
        attachScreenshot(named: "Settings-screen-URL-capture-disabled", from: application)

        application.terminate()
        application = launch(surface: "menu", state: "normal", preferencesSuite: preferencesSuite)
        assertDoesNotExist(application.buttons["menu.capture-screen-urls"])
        attachScreenshot(named: "Menu-screen-URL-capture-disabled", from: application)

        application.terminate()
        application = launch(surface: "settings", state: "normal", preferencesSuite: preferencesSuite)
        form = application.scrollViews["settings.general.form"]
        assertExists(form)
        captureToggle = application.descendants(matching: .any)["settings.screen-url-capture.toggle"].firstMatch
        for _ in 0 ..< 4 where !captureToggle.exists {
            form.swipeUp()
        }
        assertExists(captureToggle)
        XCTAssertFalse(isControlOn(captureToggle))
        captureToggle.click()
        XCTAssertTrue(isControlOn(captureToggle))
        let shortcutToggle = application.descendants(matching: .any)[
            "settings.screen-url-capture.shortcut-toggle"
        ].firstMatch
        let recorder = application.descendants(matching: .any)["settings.screen-url-capture.shortcut-field"]
        assertExists(shortcutToggle)
        XCTAssertTrue(isControlOn(shortcutToggle))
        assertExists(recorder)
        XCTAssertEqual(shortcutValue(recorder), "⌥⌘C")
    }

    @MainActor
    func verifyCapturePermissionAndAvailabilityStates(in application: inout XCUIApplication) {
        application.terminate()
        application = launch(surface: "settings", state: "screen-capture-denied")
        var form = application.scrollViews["settings.general.form"]
        assertExists(form)
        let requestAccess = application.buttons["settings.screen-url-capture.request-access"]
        let openSettings = application.buttons["settings.screen-url-capture.open-system-settings"]
        for _ in 0 ..< 4 where !openSettings.exists {
            form.swipeUp()
        }
        assertExists(requestAccess)
        assertExists(openSettings)
        attachScreenshot(named: "Settings-screen-URL-permission-required", from: application)

        application.terminate()
        application = launch(surface: "settings", state: "vision-unavailable")
        form = application.scrollViews["settings.general.form"]
        assertExists(form)
        let captureToggle = application.descendants(matching: .any)["settings.screen-url-capture.toggle"].firstMatch
        for _ in 0 ..< 4 where !captureToggle.exists {
            form.swipeUp()
        }
        assertExists(captureToggle)
        XCTAssertFalse(captureToggle.isEnabled)
        assertExists(application.staticTexts["settings.screen-url-capture.unavailable"])
        assertDoesNotExist(
            application.descendants(matching: .any)["settings.screen-url-capture.shortcut-toggle"]
        )
        attachScreenshot(named: "Settings-screen-URL-capture-unavailable", from: application)
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

    @MainActor
    func assertSelected(
        _ element: XCUIElement,
        message: String = "Expected UI element did not become selected"
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == true"),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 5),
            .completed,
            message
        )
    }

    @MainActor
    func assertRemainsSelected(
        _ element: XCUIElement,
        duration: TimeInterval = 1,
        message: String = "Expected UI element to remain selected"
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == false"),
            object: element
        )
        expectation.isInverted = true
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: duration),
            .completed,
            message
        )
    }

    @MainActor
    func assertDoesNotExist(
        _ element: XCUIElement,
        message: String = "Expected UI element not to appear"
    ) {
        let exists = element.waitForExistence(
            timeout: 1
        )
        XCTAssertFalse(
            exists,
            message
        )
    }

    @MainActor
    func makeHittable(
        _ element: XCUIElement,
        in container: XCUIElement,
        scrolling direction: ScrollDirection
    ) {
        for _ in 0 ..< 5 where !element.isHittable {
            switch direction {
            case .up:
                container.swipeUp()
            case .down:
                container.swipeDown()
            }
        }

        XCTAssertTrue(element.isHittable, "Expected UI element to become hittable")
    }

    @MainActor
    func accessibilityCopy(
        in element: XCUIElement
    ) -> String {
        let ownValue = element.value.map(String.init(describing:)) ?? ""
        let descendantCopy = element
            .descendants(matching: .staticText)
            .allElementsBoundByIndex
            .map { child in
                let value = child.value.map(String.init(describing:)) ?? ""
                return "\(child.label) \(value)"
            }
            .joined(separator: " ")

        return "\(element.label) \(ownValue) \(descendantCopy)"
    }
}

// swiftlint:enable file_length type_body_length
