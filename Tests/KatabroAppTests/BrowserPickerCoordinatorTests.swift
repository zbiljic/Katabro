import AppKit
@testable import Katabro
import KatabroCore
import Testing

// Coordinator scenarios intentionally share stateful test doubles and helpers.
// swiftlint:disable file_length

@MainActor
@Suite("Browser picker routing")
struct BrowserPickerCoordinatorTests { // swiftlint:disable:this type_body_length
    enum TestError: Error {
        case expected
    }

    @Test("clipboard command reads once and routes the returned URL")
    func opensClipboardURL() async throws {
        let browser = makeBrowser()
        let discovery = BrowserDiscoveryFake(browsers: [browser])
        var readCount = 0
        let destination = try #require(
            URL(string: "https://example.com/clipboard")
        )
        let menuActionScheduler = ControlledMenuActionScheduler()
        let coordinator = makeCoordinator(
            discovery: discovery,
            launcher: BrowserLauncherFake(),
            clipboardURLClient: ClipboardURLClient {
                readCount += 1
                return destination
            },
            menuActionScheduler: menuActionScheduler
        )

        coordinator.openClipboardURL()
        #expect(readCount == 1)
        #expect(discovery.destinations.isEmpty)
        #expect(coordinator.presentedStore == nil)

        menuActionScheduler.runPendingCompletion()
        await coordinator.waitForPendingOperations()
        let expectedDestination = try IncomingURL(destination)

        #expect(readCount == 1)
        #expect(discovery.destinations == [expectedDestination])
        #expect(coordinator.presentedStore?.destination == expectedDestination)

        menuActionScheduler.runPendingCompletion()
        await coordinator.waitForPendingOperations()
        #expect(discovery.destinations == [expectedDestination])
    }

    @Test("empty clipboard presents an error without routing side effects")
    func rejectsEmptyClipboard() {
        var readCount = 0
        var preferenceWriteCount = 0
        let discovery = BrowserDiscoveryFake()
        let launcher = BrowserLauncherFake()
        let errorPresenter = RoutingErrorPresenterFake()
        let presentation = BrowserPickerPresentationFake()
        let menuActionScheduler = ControlledMenuActionScheduler()
        let preferencesStore = PreferencesStore { _ in
            preferenceWriteCount += 1
        }
        let coordinator = makeCoordinator(
            discovery: discovery,
            launcher: launcher,
            errorPresenter: errorPresenter,
            preferencesStore: preferencesStore,
            clipboardURLClient: ClipboardURLClient {
                readCount += 1
                return nil
            },
            menuActionScheduler: menuActionScheduler
        ) { _, _, _, _ in
            presentation
        }

        coordinator.openClipboardURL()

        #expect(readCount == 1)
        #expect(errorPresenter.presentedErrors.isEmpty)
        #expect(discovery.destinations.isEmpty)
        #expect(launcher.openedRequests.isEmpty)
        #expect(!presentation.isPresented)
        #expect(preferenceWriteCount == 0)
        #expect(coordinator.pendingRequestCount == 0)
        #expect(coordinator.presentedStore == nil)

        menuActionScheduler.runPendingCompletion()

        #expect(errorPresenter.presentedErrors == ["noRoutableURL"])
        #expect(discovery.destinations.isEmpty)
        #expect(launcher.openedRequests.isEmpty)
        #expect(!presentation.isPresented)
        #expect(preferenceWriteCount == 0)
        #expect(coordinator.pendingRequestCount == 0)
        #expect(coordinator.presentedStore == nil)

        menuActionScheduler.runPendingCompletion()
        #expect(errorPresenter.presentedErrors == ["noRoutableURL"])
    }

    @Test("new presentations capture the latest picker preference snapshot")
    func capturesLatestPickerPreferences() async throws {
        let browser = makeBrowser()
        let preferencesStore = PreferencesStore()
        let firstPreferences = BrowserPickerPreferences(orientation: .horizontal, visibleChoiceCount: 3)
        preferencesStore.setPickerPreferences(firstPreferences)
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(browsers: [browser]),
            launcher: BrowserLauncherFake(),
            preferencesStore: preferencesStore
        )

        try coordinator.route(RoutingRequest(
            destination: IncomingURL("https://example.com"),
            source: .system
        ))
        await coordinator.waitForPendingOperations()
        #expect(coordinator.presentedStore?.pickerPreferences == firstPreferences)

        preferencesStore.setPickerPreferences(BrowserPickerPreferences(orientation: .vertical, visibleChoiceCount: 8))
        #expect(coordinator.presentedStore?.pickerPreferences == firstPreferences)
    }

    @Test("preview opens example.com without routing or remembering")
    func previewsWithoutRoutingOrRemembering() async throws { // swiftlint:disable:this function_body_length
        let first = makeBrowser(
            identifier: "com.example.first",
            name: "First"
        )
        let second = makeBrowser(
            identifier: "com.example.second",
            name: "Second"
        )
        let hidden = makeBrowser(
            identifier: "com.example.hidden",
            name: "Hidden"
        )
        let pickerPreferences = BrowserPickerPreferences(
            orientation: .horizontal,
            verticalWidth: .compact,
            visibleChoiceCount: 3,
            destinationDisplay: .fullURL,
            shortcutHintMode: .hidden,
            horizontalLabelMode: .all,
            showsRememberChoice: true
        )
        let existingRule = try #require(
            ExactHostRoutingRule(
                host: "existing.example",
                targetIdentifier: makeTarget(first).id
            )
        )
        var preferenceWriteCount = 0
        let preferencesStore = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: [
                    second.browser.bundleIdentifier,
                    hidden.browser.bundleIdentifier,
                    first.browser.bundleIdentifier,
                ],
                hiddenBrowserIdentifiers: [hidden.browser.bundleIdentifier],
                exactHostRoutingRules: [existingRule],
                pickerPreferences: pickerPreferences
            )
        ) { _ in
            preferenceWriteCount += 1
        }
        let discovery = BrowserDiscoveryFake(
            browsers: [first, second, hidden]
        )
        let launcher = BrowserLauncherFake()
        var routingDecisionCount = 0
        var selectionHandler: ((BrowserLaunchTarget, Bool) -> Void)?
        let presentation = BrowserPickerPresentationFake()
        let coordinator = makeCoordinator(
            discovery: discovery,
            launcher: launcher,
            preferencesStore: preferencesStore,
            routingDecisionClient: RoutingDecisionClient { _, _ in
                routingDecisionCount += 1
                return .open(targetIdentifier: makeTarget(first).id)
            }
        ) { _, onSelect, _, _ in
            selectionHandler = onSelect
            return presentation
        }

        coordinator.preview()
        await coordinator.waitForPendingOperations()

        let previewDestination = try IncomingURL("https://example.com")
        #expect(discovery.destinations == [previewDestination])
        #expect(coordinator.presentedStore?.destination == previewDestination)
        #expect(coordinator.presentedStore?.pickerPreferences == pickerPreferences)
        #expect(coordinator.presentedStore?.targets == [makeTarget(second), makeTarget(first)])
        #expect(routingDecisionCount == 0)
        #expect(presentation.isPresented)

        coordinator.presentedStore?.setRememberingSelection(true)
        let select = try #require(selectionHandler)
        select(makeTarget(second), true)
        await coordinator.waitForPendingOperations()

        #expect(
            launcher.openedRequests == [
                BrowserLauncherFake.OpenedRequest(
                    destination: previewDestination,
                    target: makeTarget(second)
                ),
            ]
        )
        #expect(preferenceWriteCount == 0)
        #expect(preferencesStore.exactHostRoutingRules == [existingRule])
        #expect(presentation.isClosed)
        #expect(coordinator.presentedStore == nil)
    }

    @Test("preview cancellation dismisses without system actions")
    func cancelsPreview() async throws {
        let launcher = BrowserLauncherFake()
        var cancellationHandler: (() -> Void)?
        let presentation = BrowserPickerPresentationFake()
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(browsers: [makeBrowser()]),
            launcher: launcher
        ) { _, _, _, onCancel in
            cancellationHandler = onCancel
            return presentation
        }

        coordinator.preview()
        await coordinator.waitForPendingOperations()
        let cancel = try #require(cancellationHandler)
        cancel()

        #expect(presentation.isClosed)
        #expect(coordinator.presentedStore == nil)
        #expect(launcher.openedRequests.isEmpty)
    }

    @Test("discovers browsers and launches the selected browser")
    func launchesSelection() async throws {
        let browser = makeBrowser()
        let discovery = BrowserDiscoveryFake(
            browsers: [browser]
        )
        let launcher = BrowserLauncherFake()
        var selectionHandler: ((BrowserLaunchTarget, Bool) -> Void)?
        let coordinator = makeCoordinator(
            discovery: discovery,
            launcher: launcher
        ) { _, onSelect, _, _ in
            selectionHandler = onSelect
            return BrowserPickerPresentationFake()
        }
        let request = try RoutingRequest(
            destination: IncomingURL("https://example.com/path"),
            source: .system
        )

        coordinator.route(request)
        await coordinator.waitForPendingOperations()

        #expect(discovery.destinations == [request.destination])
        #expect(coordinator.presentedStore?.browsers == [browser])

        let selectBrowser = try #require(selectionHandler)
        selectBrowser(makeTarget(browser), false)
        await coordinator.waitForPendingOperations()

        #expect(
            launcher.openedRequests == [
                BrowserLauncherFake.OpenedRequest(
                    destination: request.destination,
                    target: makeTarget(browser)
                ),
            ]
        )
        #expect(coordinator.presentedStore == nil)
        #expect(coordinator.lastError == nil)
    }

    @Test("records discovery failures without presenting")
    func handlesDiscoveryFailure() async throws {
        let discovery = BrowserDiscoveryFake(
            error: TestError.expected
        )
        let launcher = BrowserLauncherFake()
        let errorPresenter = RoutingErrorPresenterFake()
        let coordinator = makeCoordinator(
            discovery: discovery,
            launcher: launcher,
            errorPresenter: errorPresenter
        )
        let request = try RoutingRequest(
            destination: IncomingURL("https://example.com"),
            source: .system
        )

        coordinator.route(request)
        await coordinator.waitForPendingOperations()

        #expect(coordinator.presentedStore == nil)
        #expect(coordinator.lastError == "expected")
        #expect(errorPresenter.presentedErrors == ["expected"])
        #expect(launcher.openedRequests.isEmpty)
    }

    @Test("presents an empty discovery result without inventing a selection")
    func handlesEmptyDiscovery() async throws {
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(),
            launcher: BrowserLauncherFake()
        )

        try coordinator.route(
            RoutingRequest(
                destination: IncomingURL("https://example.com"),
                source: .system
            )
        )
        await coordinator.waitForPendingOperations()

        #expect(coordinator.presentedStore?.browsers.isEmpty == true)
        #expect(coordinator.presentedStore?.selectedBrowser == nil)
    }

    @Test("excludes hidden browsers while preserving visible order")
    func filtersHiddenBrowsers() async throws {
        let first = makeBrowser(
            identifier: "com.example.first",
            name: "First"
        )
        let second = makeBrowser(
            identifier: "com.example.second",
            name: "Second"
        )
        let third = makeBrowser(
            identifier: "com.example.third",
            name: "Third"
        )
        let preferencesStore = PreferencesStore(
            initialPreferences: AppPreferences(
                browserOrder: [
                    "com.example.third",
                    "com.example.second",
                    "com.example.first",
                ],
                hiddenBrowserIdentifiers: ["com.example.second"]
            )
        )
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(
                browsers: [first, second, third]
            ),
            launcher: BrowserLauncherFake(),
            preferencesStore: preferencesStore
        )

        try coordinator.route(
            RoutingRequest(
                destination: IncomingURL("https://example.com"),
                source: .system
            )
        )
        await coordinator.waitForPendingOperations()

        #expect(
            coordinator.presentedStore?.browsers == [third, first]
        )
    }

    @Test("falls back to the first ordered browser when all are hidden")
    func fallsBackWhenAllBrowsersAreHidden() async throws {
        let first = makeBrowser(
            identifier: "com.example.first",
            name: "First"
        )
        let second = makeBrowser(
            identifier: "com.example.second",
            name: "Second"
        )
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(
                browsers: [first, second]
            ),
            launcher: BrowserLauncherFake(),
            preferencesStore: PreferencesStore(
                initialPreferences: AppPreferences(
                    browserOrder: [
                        "com.example.second",
                        "com.example.first",
                    ],
                    hiddenBrowserIdentifiers: [
                        "com.example.first",
                        "com.example.second",
                    ]
                )
            )
        )

        try coordinator.route(
            RoutingRequest(
                destination: IncomingURL("https://example.com"),
                source: .system
            )
        )
        await coordinator.waitForPendingOperations()

        #expect(coordinator.presentedStore?.browsers == [second])
    }

    @Test("records a browser launch failure after dismissing")
    func handlesLaunchFailure() async throws {
        let browser = makeBrowser()
        let discovery = BrowserDiscoveryFake(
            browsers: [browser]
        )
        let launcher = BrowserLauncherFake(
            error: TestError.expected
        )
        let errorPresenter = RoutingErrorPresenterFake()
        var selectionHandler: ((BrowserLaunchTarget, Bool) -> Void)?
        let coordinator = makeCoordinator(
            discovery: discovery,
            launcher: launcher,
            errorPresenter: errorPresenter
        ) { _, onSelect, _, _ in
            selectionHandler = onSelect
            return BrowserPickerPresentationFake()
        }

        try coordinator.route(
            RoutingRequest(
                destination: IncomingURL("https://example.com"),
                source: .system
            )
        )
        await coordinator.waitForPendingOperations()

        let selectBrowser = try #require(selectionHandler)
        selectBrowser(makeTarget(browser), false)
        await coordinator.waitForPendingOperations()

        #expect(coordinator.presentedStore == nil)
        #expect(coordinator.lastError == "expected")
        #expect(errorPresenter.presentedErrors == ["expected"])
    }
}

extension BrowserPickerCoordinatorTests {
    @Test("serializes repeated selection callbacks")
    func serializesSelection() async throws {
        let browser = makeBrowser()
        let launcher = SuspendedBrowserLauncher()
        var selectionHandler: ((BrowserLaunchTarget, Bool) -> Void)?
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(
                browsers: [browser]
            ),
            launcher: launcher
        ) { _, onSelect, _, _ in
            selectionHandler = onSelect
            return BrowserPickerPresentationFake()
        }

        try coordinator.route(
            RoutingRequest(
                destination: IncomingURL("https://example.com"),
                source: .system
            )
        )
        await coordinator.waitForPendingOperations()

        let selectBrowser = try #require(selectionHandler)
        selectBrowser(makeTarget(browser), false)
        selectBrowser(makeTarget(browser), false)
        await launcher.waitForRequest()

        #expect(launcher.requestCount == 1)

        launcher.succeed()
        await coordinator.waitForPendingOperations()
    }

    @Test("queues a second request while the picker is active")
    func queuesConcurrentRequest() async throws {
        let discovery = BrowserDiscoveryFake(
            browsers: [makeBrowser()]
        )
        let coordinator = makeCoordinator(
            discovery: discovery,
            launcher: BrowserLauncherFake()
        )
        let firstRequest = try RoutingRequest(
            destination: IncomingURL("https://one.example"),
            source: .system
        )
        let secondRequest = try RoutingRequest(
            destination: IncomingURL("https://two.example"),
            source: .system
        )

        coordinator.route(firstRequest)
        await coordinator.waitForPendingOperations()
        coordinator.route(secondRequest)
        await coordinator.waitForPendingOperations()

        #expect(discovery.destinations == [firstRequest.destination])
        #expect(coordinator.presentedStore?.destination == firstRequest.destination)
        #expect(coordinator.pendingRequestCount == 1)

        coordinator.cancel()
        await coordinator.waitForPendingOperations()

        #expect(
            discovery.destinations == [
                firstRequest.destination,
                secondRequest.destination,
            ]
        )
        #expect(coordinator.presentedStore?.destination == secondRequest.destination)
        #expect(coordinator.pendingRequestCount == 0)
    }

    @Test("copying preserves the exact URL and completes without launching")
    func copiesExactURLAndCompletes() async throws {
        let launcher = BrowserLauncherFake()
        let presentation = BrowserPickerPresentationFake()
        var copiedURLs: [URL] = []
        var copyHandler: (() -> Void)?
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(browsers: [makeBrowser()]),
            launcher: launcher,
            clipboardURLClient: ClipboardURLClient(
                currentURLHandler: { nil },
                copyURLHandler: { copiedURLs.append($0) }
            )
        ) { _, _, onCopyLink, _ in
            copyHandler = onCopyLink
            return presentation
        }
        let request = try RoutingRequest(
            destination: IncomingURL("https://example.com/full/path?query=value#fragment"),
            source: .system
        )

        coordinator.route(request)
        await coordinator.waitForPendingOperations()
        let copy = try #require(copyHandler)
        copy()

        #expect(copiedURLs == [request.destination.url])
        #expect(launcher.openedRequests.isEmpty)
        #expect(presentation.isClosed)
        #expect(coordinator.presentedStore == nil)
        #expect(coordinator.lastError == nil)
    }

    @Test("successful copy advances the queued request")
    func successfulCopyAdvancesQueue() async throws {
        var copiedURLs: [URL] = []
        var copyHandlers: [() -> Void] = []
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(browsers: [makeBrowser()]),
            launcher: BrowserLauncherFake(),
            clipboardURLClient: ClipboardURLClient(
                currentURLHandler: { nil },
                copyURLHandler: { copiedURLs.append($0) }
            )
        ) { _, _, onCopyLink, _ in
            copyHandlers.append(onCopyLink)
            return BrowserPickerPresentationFake()
        }
        let first = try RoutingRequest(
            destination: IncomingURL("https://first.example/path"),
            source: .system
        )
        let second = try RoutingRequest(
            destination: IncomingURL("https://second.example/path"),
            source: .system
        )

        coordinator.route(first)
        await coordinator.waitForPendingOperations()
        coordinator.route(second)
        #expect(coordinator.pendingRequestCount == 1)

        let copy = try #require(copyHandlers.first)
        copy()
        await coordinator.waitForPendingOperations()

        #expect(copiedURLs == [first.destination.url])
        #expect(coordinator.presentedStore?.destination == second.destination)
        #expect(coordinator.pendingRequestCount == 0)
        #expect(copyHandlers.count == 2)
    }

    @Test("failed copy keeps the picker and queue active")
    func failedCopyRetainsRequest() async throws {
        let launcher = BrowserLauncherFake()
        let errorPresenter = RoutingErrorPresenterFake()
        let presentation = BrowserPickerPresentationFake()
        var copyCount = 0
        var copyHandler: (() -> Void)?
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(browsers: [makeBrowser()]),
            launcher: launcher,
            errorPresenter: errorPresenter,
            clipboardURLClient: ClipboardURLClient(
                currentURLHandler: { nil },
                copyURLHandler: { _ in
                    copyCount += 1
                    throw TestError.expected
                }
            )
        ) { _, _, onCopyLink, _ in
            copyHandler = onCopyLink
            return presentation
        }
        let first = try RoutingRequest(
            destination: IncomingURL("https://first.example"),
            source: .system
        )
        let second = try RoutingRequest(
            destination: IncomingURL("https://second.example"),
            source: .system
        )

        coordinator.route(first)
        await coordinator.waitForPendingOperations()
        let presentedStore = try #require(coordinator.presentedStore)
        coordinator.route(second)
        let copy = try #require(copyHandler)
        copy()

        #expect(copyCount == 1)
        #expect(errorPresenter.presentedErrors == ["expected"])
        #expect(launcher.openedRequests.isEmpty)
        #expect(presentation.isPresented)
        #expect(!presentation.isClosed)
        #expect(coordinator.presentedStore === presentedStore)
        #expect(coordinator.presentedStore?.destination == first.destination)
        #expect(coordinator.pendingRequestCount == 1)
    }

    @Test("stale copy callback cannot affect the next request")
    func staleCopyDoesNotAffectNextRequest() async throws {
        var copiedURLs: [URL] = []
        var copyHandlers: [() -> Void] = []
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(browsers: [makeBrowser()]),
            launcher: BrowserLauncherFake(),
            clipboardURLClient: ClipboardURLClient(
                currentURLHandler: { nil },
                copyURLHandler: { copiedURLs.append($0) }
            )
        ) { _, _, onCopyLink, _ in
            copyHandlers.append(onCopyLink)
            return BrowserPickerPresentationFake()
        }
        let first = try RoutingRequest(
            destination: IncomingURL("https://first.example"),
            source: .system
        )
        let second = try RoutingRequest(
            destination: IncomingURL("https://second.example"),
            source: .system
        )

        coordinator.route(first)
        await coordinator.waitForPendingOperations()
        coordinator.route(second)
        let staleCopy = try #require(copyHandlers.first)
        staleCopy()
        await coordinator.waitForPendingOperations()

        #expect(coordinator.presentedStore?.destination == second.destination)
        staleCopy()

        #expect(copiedURLs == [first.destination.url])
        #expect(coordinator.presentedStore?.destination == second.destination)
        #expect(coordinator.pendingRequestCount == 0)
    }

    @Test("queues every URL delivered in a single application event")
    func queuesURLBatch() async throws {
        let discovery = BrowserDiscoveryFake(
            browsers: [makeBrowser()]
        )
        let coordinator = makeCoordinator(
            discovery: discovery,
            launcher: BrowserLauncherFake()
        )
        let firstURL = try #require(URL(string: "https://one.example"))
        let secondURL = try #require(URL(string: "https://two.example"))

        coordinator.handle([firstURL, secondURL])
        await coordinator.waitForPendingOperations()

        #expect(
            try discovery.destinations == [
                IncomingURL(firstURL),
            ]
        )
        #expect(coordinator.pendingRequestCount == 1)

        coordinator.cancel()
        await coordinator.waitForPendingOperations()

        #expect(
            try discovery.destinations == [
                IncomingURL(firstURL),
                IncomingURL(secondURL),
            ]
        )
        #expect(coordinator.pendingRequestCount == 0)
    }

    @Test("a canceled discovery cannot overwrite the next request")
    func ignoresStaleDiscoveryFailure() async throws {
        let browser = makeBrowser()
        let discovery = CancellationRacingDiscovery(
            browsers: [browser]
        )
        let coordinator = makeCoordinator(
            discovery: discovery,
            launcher: BrowserLauncherFake()
        )
        let firstRequest = try RoutingRequest(
            destination: IncomingURL("https://one.example"),
            source: .system
        )
        let secondRequest = try RoutingRequest(
            destination: IncomingURL("https://two.example"),
            source: .system
        )

        coordinator.route(firstRequest)
        await discovery.waitForFirstRequest()
        coordinator.route(secondRequest)
        coordinator.cancel()
        await coordinator.waitForPendingOperations()

        discovery.failFirstRequest()
        await Task.yield()
        await Task.yield()

        #expect(
            discovery.destinations == [
                firstRequest.destination,
                secondRequest.destination,
            ]
        )
        #expect(coordinator.presentedStore?.destination == secondRequest.destination)
        #expect(coordinator.lastError == nil)
        #expect(coordinator.pendingRequestCount == 0)
    }

    @Test("cancels through the presentation callback")
    func cancelsPresentation() async throws {
        var cancellationHandler: (() -> Void)?
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(
                browsers: [makeBrowser()]
            ),
            launcher: BrowserLauncherFake()
        ) { _, _, _, onCancel in
            cancellationHandler = onCancel
            return BrowserPickerPresentationFake()
        }

        try coordinator.route(
            RoutingRequest(
                destination: IncomingURL("https://example.com"),
                source: .system
            )
        )
        await coordinator.waitForPendingOperations()

        let cancel = try #require(cancellationHandler)
        cancel()

        #expect(coordinator.presentedStore == nil)
    }

    @Test("routes file URLs and ignores a forced remember request")
    func routesFileURLWithoutRemembering() async throws {
        let browser = makeBrowser()
        let launcher = BrowserLauncherFake()
        let preferencesStore = PreferencesStore()
        var selectionHandler: ((BrowserLaunchTarget, Bool) -> Void)?
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(browsers: [browser]),
            launcher: launcher,
            preferencesStore: preferencesStore
        ) { _, onSelect, _, _ in
            selectionHandler = onSelect
            return BrowserPickerPresentationFake()
        }
        let fileURL = try #require(URL(string: "file://localhost/tmp/example%20page.html"))

        coordinator.handle(fileURL)
        await coordinator.waitForPendingOperations()

        #expect(coordinator.presentedStore?.destination.url.absoluteString == fileURL.absoluteString)
        #expect(coordinator.presentedStore?.canRememberSelection == false)

        let selectBrowser = try #require(selectionHandler)
        selectBrowser(makeTarget(browser), true)
        await coordinator.waitForPendingOperations()

        #expect(launcher.openedRequests.first?.destination.url.absoluteString == fileURL.absoluteString)
        #expect(preferencesStore.exactHostRoutingRules.isEmpty)
        #expect(coordinator.lastError == nil)
    }

    @Test("matching rule bypasses the picker and launches its exact target")
    func automaticallyLaunchesMatchingRule() async throws {
        let browser = makeBrowser()
        let launcher = BrowserLauncherFake()
        let request = try RoutingRequest(
            destination: IncomingURL("https://Example.com/path"),
            source: .system
        )
        let preferencesStore = PreferencesStore()
        preferencesStore.setExactHostRoutingRule(
            for: request.destination,
            targetIdentifier: makeTarget(browser).id
        )
        var panelBuildCount = 0
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(browsers: [browser]),
            launcher: launcher,
            preferencesStore: preferencesStore
        ) { _, _, _, _ in
            panelBuildCount += 1
            return BrowserPickerPresentationFake()
        }

        coordinator.route(request)
        await coordinator.waitForPendingOperations()

        #expect(panelBuildCount == 0)
        #expect(launcher.openedRequests == [
            BrowserLauncherFake.OpenedRequest(
                destination: request.destination,
                target: makeTarget(browser)
            ),
        ])
    }

    @Test("missing rule target falls back without deleting the rule")
    func missingTargetFallsBack() async throws {
        let browser = makeBrowser()
        let destination = try IncomingURL("https://example.com")
        let preferencesStore = PreferencesStore()
        preferencesStore.setExactHostRoutingRule(
            for: destination,
            targetIdentifier: "com.example.missing:profile:Work"
        )
        let launcher = BrowserLauncherFake()
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(browsers: [browser]),
            launcher: launcher,
            preferencesStore: preferencesStore
        )

        coordinator.route(
            RoutingRequest(destination: destination, source: .system)
        )
        await coordinator.waitForPendingOperations()

        #expect(coordinator.presentedStore?.targets == [makeTarget(browser)])
        #expect(launcher.openedRequests.isEmpty)
        #expect(preferencesStore.exactHostRoutingRules.count == 1)
    }

    @Test("checked selection saves only after successful launch")
    func checkedSelectionSavesAfterLaunch() async throws {
        let browser = makeBrowser()
        let preferencesStore = PreferencesStore()
        var selectionHandler: ((BrowserLaunchTarget, Bool) -> Void)?
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(browsers: [browser]),
            launcher: BrowserLauncherFake(),
            preferencesStore: preferencesStore
        ) { _, onSelect, _, _ in
            selectionHandler = onSelect
            return BrowserPickerPresentationFake()
        }
        let request = try RoutingRequest(
            destination: IncomingURL("https://example.com/private/path"),
            source: .system
        )

        coordinator.route(request)
        await coordinator.waitForPendingOperations()
        let selectBrowser = try #require(selectionHandler)
        selectBrowser(makeTarget(browser), true)
        await coordinator.waitForPendingOperations()

        let expectedRule = try #require(
            ExactHostRoutingRule(
                host: "example.com",
                targetIdentifier: makeTarget(browser).id
            )
        )
        #expect(preferencesStore.exactHostRoutingRules == [expectedRule])
    }

    @Test("failed checked launch preserves an existing rule")
    func failedCheckedLaunchPreservesRule() async throws {
        let browser = makeBrowser()
        let destination = try IncomingURL("https://example.com")
        let preferencesStore = PreferencesStore()
        preferencesStore.setExactHostRoutingRule(
            for: destination,
            targetIdentifier: "old-target"
        )
        var selectionHandler: ((BrowserLaunchTarget, Bool) -> Void)?
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(browsers: [browser]),
            launcher: BrowserLauncherFake(error: TestError.expected),
            preferencesStore: preferencesStore,
            routingDecisionClient: RoutingDecisionClient { _, _ in .ask }
        ) { _, onSelect, _, _ in
            selectionHandler = onSelect
            return BrowserPickerPresentationFake()
        }

        coordinator.route(
            RoutingRequest(destination: destination, source: .system)
        )
        await coordinator.waitForPendingOperations()
        let selectBrowser = try #require(selectionHandler)
        selectBrowser(makeTarget(browser), true)
        await coordinator.waitForPendingOperations()

        #expect(preferencesStore.exactHostRoutingRules.first?.targetIdentifier == "old-target")
    }

    @Test("hidden target remains available to automatic routing")
    func automaticallyLaunchesHiddenTarget() async throws {
        let hidden = makeBrowser(identifier: "com.example.hidden", name: "Hidden")
        let shown = makeBrowser(identifier: "com.example.shown", name: "Shown")
        let destination = try IncomingURL("https://example.com")
        let preferencesStore = PreferencesStore(
            initialPreferences: AppPreferences(
                hiddenBrowserIdentifiers: [hidden.browser.bundleIdentifier]
            )
        )
        preferencesStore.setExactHostRoutingRule(
            for: destination,
            targetIdentifier: makeTarget(hidden).id
        )
        let launcher = BrowserLauncherFake()
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(browsers: [hidden, shown]),
            launcher: launcher,
            preferencesStore: preferencesStore
        )

        coordinator.route(RoutingRequest(destination: destination, source: .system))
        await coordinator.waitForPendingOperations()

        #expect(launcher.openedRequests.first?.target == makeTarget(hidden))
        #expect(coordinator.presentedStore == nil)
    }

    @Test("automatic routing preserves private and profile target kinds")
    func automaticallyLaunchesArgumentTargets() async throws {
        let browser = makeBrowser(
            identifier: "com.google.Chrome",
            name: "Chrome"
        )
        let profile = BrowserProfile(
            identifier: "Mixed Case",
            displayName: "Work",
            launchValue: "Profile 2",
            family: .chromium
        )
        let profileStore = BrowserProfileStore(
            profilesByBrowserIdentifier: [
                browser.browser.bundleIdentifier: [profile],
            ],
            preservesUnbookmarkedProfiles: true
        )
        let bridge = UserScriptBridge(initialInstallationState: .current)
        let targets = [
            BrowserLaunchTarget(browser: browser, kind: .privateWindow(.chromium)),
            BrowserLaunchTarget(browser: browser, kind: .profile(profile)),
        ]

        for (index, target) in targets.enumerated() {
            let destination = try IncomingURL("https://example\(index).com")
            let preferencesStore = PreferencesStore()
            preferencesStore.setExactHostRoutingRule(
                for: destination,
                targetIdentifier: target.id
            )
            let launcher = BrowserLauncherFake()
            let coordinator = makeCoordinator(
                discovery: BrowserDiscoveryFake(browsers: [browser]),
                launcher: launcher,
                preferencesStore: preferencesStore,
                browserProfileStore: profileStore,
                userScriptBridge: bridge
            )

            coordinator.route(
                RoutingRequest(destination: destination, source: .system)
            )
            await coordinator.waitForPendingOperations()

            #expect(launcher.openedRequests.first?.target == target)
            #expect(coordinator.presentedStore == nil)
        }
    }

    @Test("unavailable private and profile targets fall back without substitution")
    func unavailableArgumentTargetsFallBack() async throws {
        let browser = makeBrowser(
            identifier: "com.google.Chrome",
            name: "Chrome"
        )
        let missingTargets = [
            BrowserLaunchTarget(browser: browser, kind: .privateWindow(.chromium)).id,
            BrowserLaunchTarget(
                browser: browser,
                kind: .profile(
                    BrowserProfile(
                        identifier: "Missing",
                        displayName: "Missing",
                        launchValue: "Missing",
                        family: .chromium
                    )
                )
            ).id,
        ]

        for (index, targetIdentifier) in missingTargets.enumerated() {
            let destination = try IncomingURL("https://missing\(index).example")
            let preferencesStore = PreferencesStore()
            preferencesStore.setExactHostRoutingRule(
                for: destination,
                targetIdentifier: targetIdentifier
            )
            let launcher = BrowserLauncherFake()
            let coordinator = makeCoordinator(
                discovery: BrowserDiscoveryFake(browsers: [browser]),
                launcher: launcher,
                preferencesStore: preferencesStore
            )

            coordinator.route(
                RoutingRequest(destination: destination, source: .system)
            )
            await coordinator.waitForPendingOperations()

            #expect(launcher.openedRequests.isEmpty)
            #expect(coordinator.presentedStore?.targets == [makeTarget(browser)])
            #expect(preferencesStore.exactHostRoutingRules.first?.targetIdentifier == targetIdentifier)
        }
    }

    @Test("queued automatic decisions launch in FIFO order")
    func queuesAutomaticDecisionsInOrder() async throws {
        let browser = makeBrowser()
        let first = try IncomingURL("https://first.example")
        let second = try IncomingURL("https://second.example")
        let preferencesStore = PreferencesStore()

        for destination in [first, second] {
            preferencesStore.setExactHostRoutingRule(
                for: destination,
                targetIdentifier: makeTarget(browser).id
            )
        }

        let launcher = BrowserLauncherFake()
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(browsers: [browser]),
            launcher: launcher,
            preferencesStore: preferencesStore
        )

        coordinator.route(RoutingRequest(destination: first, source: .system))
        coordinator.route(RoutingRequest(destination: second, source: .system))
        await coordinator.waitForPendingOperations()

        #expect(launcher.openedRequests.map(\.destination) == [first, second])
    }

    @Test("canceled suspended decision cannot affect the next request")
    func cancelsSuspendedDecision() async throws {
        let browser = makeBrowser()
        let decision = SuspendedRoutingDecision()
        let launcher = BrowserLauncherFake()
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(browsers: [browser]),
            launcher: launcher,
            routingDecisionClient: decision.client
        )
        let first = try RoutingRequest(
            destination: IncomingURL("https://first.example"),
            source: .system
        )
        let second = try RoutingRequest(
            destination: IncomingURL("https://second.example"),
            source: .system
        )

        coordinator.route(first)
        await decision.waitForFirstRequest()
        coordinator.cancel()
        coordinator.route(second)
        decision.resumeFirst(with: .open(targetIdentifier: makeTarget(browser).id))
        await coordinator.waitForPendingOperations()

        #expect(launcher.openedRequests.isEmpty)
        #expect(coordinator.presentedStore?.destination == second.destination)
    }

    private func makeCoordinator(
        discovery: any BrowserDiscovering,
        launcher: any BrowserLaunching,
        errorPresenter: RoutingErrorPresenterFake = RoutingErrorPresenterFake(),
        preferencesStore: PreferencesStore = PreferencesStore(),
        routingDecisionClient: RoutingDecisionClient = .exactHostRules,
        browserProfileStore: BrowserProfileStore = BrowserProfileStore(),
        clipboardURLClient: ClipboardURLClient = .development(url: nil),
        menuActionScheduler: any MenuActionScheduling = MenuTrackingActionScheduler(),
        userScriptBridge: UserScriptBridge = UserScriptBridge(
            initialInstallationState: .missing
        ),
        panelBuilder: @escaping BrowserPickerCoordinator.PanelBuilder = { _, _, _, _ in
            BrowserPickerPresentationFake()
        }
    ) -> BrowserPickerCoordinator {
        BrowserPickerCoordinator(
            dependencies: AppDependencies(
                browserDiscovery: discovery,
                browserLauncher: launcher,
                defaultBrowserClient: DefaultBrowserClient(
                    appBundleIdentifier: "com.example.Katabro",
                    currentHandler: { _ in
                        "com.example.browser"
                    },
                    requestHandler: { _ in }
                ),
                errorPresenter: errorPresenter,
                loginItemClient: LoginItemClient(
                    statusProvider: {
                        .disabled
                    },
                    updateHandler: { _ in }
                ),
                routingDecisionClient: routingDecisionClient,
                browserProfileStore: browserProfileStore,
                preferencesStore: preferencesStore,
                clipboardURLClient: clipboardURLClient,
                userScriptBridge: userScriptBridge
            ),
            menuActionScheduler: menuActionScheduler,
            panelBuilder: panelBuilder
        )
    }

    private final class ControlledMenuActionScheduler: MenuActionScheduling {
        private var pendingCompletion: (@MainActor () -> Void)?

        func schedule(
            _ action: @escaping @MainActor () -> Void
        ) {
            pendingCompletion = action
        }

        func runPendingCompletion() {
            let completion = pendingCompletion
            pendingCompletion = nil
            completion?()
        }
    }

    private func makeBrowser(
        identifier: String = "com.example.browser",
        name: String = "Example Browser"
    ) -> BrowserApplication {
        BrowserApplication(
            browser: Browser(
                bundleIdentifier: identifier,
                displayName: name
            ),
            applicationURL: URL(
                fileURLWithPath: "/Applications/\(name).app"
            ),
            icon: NSImage(
                size: NSSize(
                    width: 32,
                    height: 32
                )
            )
        )
    }

    private func makeTarget(
        _ browser: BrowserApplication
    ) -> BrowserLaunchTarget {
        BrowserLaunchTarget(
            browser: browser,
            kind: .standard
        )
    }
}

// swiftlint:enable file_length
