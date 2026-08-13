import AppKit
import KatabroCore

@MainActor
final class BrowserPickerCoordinator: NSObject {
    typealias PanelBuilder = @MainActor (
        _ store: BrowserPickerStore,
        _ onSelect: @escaping (BrowserApplication) -> Void,
        _ onCancel: @escaping () -> Void
    ) -> any BrowserPickerPresenting

    private let dependencies: AppDependencies
    private let panelBuilder: PanelBuilder
    private var launchTask: Task<Void, Never>?
    private var panel: (any BrowserPickerPresenting)?
    private var request: RoutingRequest?
    private var requestQueue = RoutingRequestQueue()
    private var routingTask: Task<Void, Never>?

    private(set) var lastError: String?
    var pendingRequestCount: Int {
        requestQueue.count
    }

    private(set) var presentedStore: BrowserPickerStore?

    init(
        dependencies: AppDependencies,
        panelBuilder: @escaping PanelBuilder = { store, onSelect, onCancel in
            let view = BrowserPickerView(
                store: store,
                onSelect: onSelect,
                onCancel: onCancel
            )

            return BrowserPickerPanel(
                rootView: view,
                browserCount: store.browsers.count
            )
        }
    ) {
        self.dependencies = dependencies
        self.panelBuilder = panelBuilder
    }

    func handle(
        _ urls: [URL]
    ) {
        for url in urls {
            handle(url)
        }
    }

    func handle(
        _ url: URL
    ) {
        do {
            let request: RoutingRequest = if url.scheme?.lowercased() == KatabroCore.transportScheme {
                try RoutingRequest(
                    destination: KatabroURL.decode(url),
                    source: .customURL
                )
            } else {
                try RoutingRequest(
                    destination: IncomingURL(url),
                    source: .system
                )
            }

            route(request)
        } catch {
            record(error)
        }
    }

    func route(
        _ request: RoutingRequest
    ) {
        guard self.request == nil else {
            requestQueue.enqueue(request)
            return
        }

        start(request)
    }

    func cancel() {
        finishCurrentRequest()
    }

    func waitForPendingOperations() async {
        let pendingRoutingTask = routingTask
        await pendingRoutingTask?.value

        let pendingLaunchTask = launchTask
        await pendingLaunchTask?.value
    }

    private func start(
        _ request: RoutingRequest
    ) {
        self.request = request
        lastError = nil

        routingTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let discoveredBrowsers = try await dependencies.browserDiscovery.browsers(
                    for: request.destination
                )
                let orderedBrowsers = dependencies.preferencesStore.orderedBrowsers(
                    discoveredBrowsers
                )
                let browsers = dependencies.preferencesStore.effectiveVisibleBrowsers(
                    orderedBrowsers
                )

                guard
                    !Task.isCancelled,
                    self.request?.id == request.id
                else {
                    return
                }

                present(
                    request: request,
                    browsers: browsers
                )
                routingTask = nil
            } catch {
                guard
                    !Task.isCancelled,
                    self.request?.id == request.id
                else {
                    return
                }

                record(error)
                routingTask = nil
                finishCurrentRequest(
                    id: request.id
                )
            }
        }
    }

    private func present(
        request: RoutingRequest,
        browsers: [BrowserApplication]
    ) {
        let store = BrowserPickerStore(
            destination: request.destination,
            browsers: browsers,
            pickerShortcuts: dependencies.preferencesStore.pickerShortcuts
        )
        presentedStore = store

        let panel = panelBuilder(
            store,
            { [weak self] browser in
                self?.select(browser)
            },
            { [weak self] in
                self?.cancel()
            }
        )

        panel.delegate = self
        self.panel = panel
        panel.presentNearPointer()
    }

    private func select(
        _ browser: BrowserApplication
    ) {
        guard launchTask == nil else {
            return
        }

        guard let request else {
            finishCurrentRequest()
            return
        }

        hidePanel()

        launchTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await dependencies.browserLauncher.open(
                    request.destination,
                    with: browser
                )
            } catch {
                record(error)
            }

            launchTask = nil
            finishCurrentRequest(
                id: request.id
            )
        }
    }

    private func finishCurrentRequest(
        id: UUID? = nil,
        closePanel: Bool = true
    ) {
        guard id == nil || request?.id == id else {
            return
        }

        routingTask?.cancel()
        routingTask = nil
        request = nil

        if closePanel {
            hidePanel()
        } else {
            presentedStore = nil
            panel = nil
        }

        if let nextRequest = requestQueue.dequeue() {
            start(nextRequest)
        }
    }

    private func hidePanel() {
        presentedStore = nil

        panel?.delegate = nil
        panel?.close()
        panel = nil
    }

    private func record(
        _ error: any Error
    ) {
        lastError = String(describing: error)
        dependencies.errorPresenter.present(error)
    }
}

extension BrowserPickerCoordinator: NSWindowDelegate {
    func windowDidResignKey(
        _ notification: Notification
    ) {
        guard notification.object as? BrowserPickerPanel === panel else {
            return
        }

        finishCurrentRequest()
    }

    func windowWillClose(
        _ notification: Notification
    ) {
        guard notification.object as? BrowserPickerPanel === panel else {
            return
        }

        finishCurrentRequest(
            closePanel: false
        )
    }
}
