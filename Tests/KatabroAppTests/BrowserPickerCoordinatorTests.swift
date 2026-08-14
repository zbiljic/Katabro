import AppKit
@testable import Katabro
import KatabroCore
import Testing

@MainActor
@Suite("Browser picker routing")
struct BrowserPickerCoordinatorTests {
    enum TestError: Error {
        case expected
    }

    @Test("discovers browsers and launches the selected browser")
    func launchesSelection() async throws {
        let browser = makeBrowser()
        let discovery = BrowserDiscoveryFake(
            browsers: [browser]
        )
        let launcher = BrowserLauncherFake()
        var selectionHandler: ((BrowserLaunchTarget) -> Void)?
        let coordinator = makeCoordinator(
            discovery: discovery,
            launcher: launcher
        ) { _, onSelect, _ in
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
        selectBrowser(makeTarget(browser))
        await coordinator.waitForPendingOperations()

        #expect(
            launcher.openedRequests == [
                BrowserLauncherFake.OpenedRequest(
                    destination: request.destination,
                    browser: browser
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
        var selectionHandler: ((BrowserLaunchTarget) -> Void)?
        let coordinator = makeCoordinator(
            discovery: discovery,
            launcher: launcher,
            errorPresenter: errorPresenter
        ) { _, onSelect, _ in
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
        selectBrowser(makeTarget(browser))
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
        var selectionHandler: ((BrowserLaunchTarget) -> Void)?
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(
                browsers: [browser]
            ),
            launcher: launcher
        ) { _, onSelect, _ in
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
        selectBrowser(makeTarget(browser))
        selectBrowser(makeTarget(browser))
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
        ) { _, _, onCancel in
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

    @Test("reports invalid incoming URLs to the user")
    func reportsInvalidURL() throws {
        let errorPresenter = RoutingErrorPresenterFake()
        let coordinator = makeCoordinator(
            discovery: BrowserDiscoveryFake(),
            launcher: BrowserLauncherFake(),
            errorPresenter: errorPresenter
        )
        let invalidURL = try #require(URL(string: "file:///tmp/example"))

        coordinator.handle(invalidURL)

        #expect(errorPresenter.presentedErrors.count == 1)
        #expect(coordinator.lastError != nil)
    }

    private func makeCoordinator(
        discovery: any BrowserDiscovering,
        launcher: any BrowserLaunching,
        errorPresenter: RoutingErrorPresenterFake = RoutingErrorPresenterFake(),
        preferencesStore: PreferencesStore = PreferencesStore(),
        panelBuilder: @escaping BrowserPickerCoordinator.PanelBuilder = { _, _, _ in
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
                preferencesStore: preferencesStore
            ),
            panelBuilder: panelBuilder
        )
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
