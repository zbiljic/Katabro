import AppKit
import KatabroCore

@MainActor
final class BrowserPickerCoordinator: NSObject {
    typealias PanelBuilder = @MainActor (
        _ store: BrowserPickerStore,
        _ onSelect: @escaping (BrowserApplication) -> Void,
        _ onCancel: @escaping () -> Void
    ) -> BrowserPickerPanel?

    private let dependencies: AppDependencies
    private let panelBuilder: PanelBuilder
    private var launchTask: Task<Void, Never>?
    private var panel: BrowserPickerPanel?
    private var request: RoutingRequest?
    private var routingTask: Task<Void, Never>?

    private(set) var lastError: String?
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
            lastError = String(describing: error)
        }
    }

    func route(
        _ request: RoutingRequest
    ) {
        guard self.request == nil else {
            return
        }

        self.request = request
        lastError = nil

        routingTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let browsers = try await dependencies.browserDiscovery.browsers(
                    for: request.destination
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
            } catch {
                lastError = String(describing: error)
                self.request = nil
            }

            routingTask = nil
        }
    }

    func cancel() {
        dismiss()
    }

    func waitForPendingOperations() async {
        let pendingRoutingTask = routingTask
        await pendingRoutingTask?.value

        let pendingLaunchTask = launchTask
        await pendingLaunchTask?.value
    }

    private func present(
        request: RoutingRequest,
        browsers: [BrowserApplication]
    ) {
        let store = BrowserPickerStore(
            destination: request.destination,
            browsers: browsers
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

        guard let panel else {
            return
        }

        panel.delegate = self
        self.panel = panel
        panel.presentNearPointer()
    }

    private func select(
        _ browser: BrowserApplication
    ) {
        guard let request else {
            dismiss()
            return
        }

        dismiss()

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
                lastError = String(describing: error)
            }

            launchTask = nil
        }
    }

    private func dismiss() {
        routingTask?.cancel()
        routingTask = nil
        request = nil
        presentedStore = nil

        panel?.delegate = nil
        panel?.close()
        panel = nil
    }
}

extension BrowserPickerCoordinator: NSWindowDelegate {
    func windowDidResignKey(
        _ notification: Notification
    ) {
        guard notification.object as? BrowserPickerPanel === panel else {
            return
        }

        dismiss()
    }

    func windowWillClose(
        _ notification: Notification
    ) {
        guard notification.object as? BrowserPickerPanel === panel else {
            return
        }

        request = nil
        presentedStore = nil
        panel = nil
    }
}
