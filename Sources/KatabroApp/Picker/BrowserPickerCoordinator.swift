import AppKit
import KatabroCore

@MainActor
final class BrowserPickerCoordinator: NSObject {
    typealias PanelBuilder = @MainActor (
        _ store: BrowserPickerStore,
        _ onSelect: @escaping (BrowserLaunchTarget, Bool) -> Void,
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
                browserCount: store.targets.count
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
        while routingTask != nil || launchTask != nil {
            let pendingRoutingTask = routingTask
            await pendingRoutingTask?.value

            let pendingLaunchTask = launchTask
            await pendingLaunchTask?.value
        }
    }

    // Discovery, decision, target construction, and stale-request guards stay
    // together so their ordering is explicit.
    // swiftlint:disable:next function_body_length
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
                guard
                    !Task.isCancelled,
                    self.request?.id == request.id
                else {
                    return
                }

                let decision = await dependencies.routingDecisionClient.decision(
                    for: request,
                    rules: dependencies.preferencesStore.exactHostRoutingRules
                )

                guard
                    !Task.isCancelled,
                    self.request?.id == request.id
                else {
                    return
                }

                dependencies.userScriptBridge.refresh()
                for browser in orderedBrowsers {
                    dependencies.browserProfileStore.refresh(
                        for: browser
                    )
                }
                let allTargets = dependencies.browserProfileStore.targets(
                    for: orderedBrowsers,
                    includesArgumentTargets: dependencies.userScriptBridge.isInstalled
                )

                guard
                    !Task.isCancelled,
                    self.request?.id == request.id
                else {
                    return
                }

                routingTask = nil

                let automaticTarget: BrowserLaunchTarget? = if case let .open(targetIdentifier) = decision {
                    allTargets.first { $0.id == targetIdentifier }
                } else {
                    nil
                }
                if let target = automaticTarget {
                    launch(
                        request: request,
                        target: target,
                        ruleIntent: nil
                    )
                    return
                }

                let visibleBrowsers = dependencies.preferencesStore.effectiveVisibleBrowsers(
                    orderedBrowsers
                )
                let visibleTargets = dependencies.browserProfileStore.targets(
                    for: visibleBrowsers,
                    includesArgumentTargets: dependencies.userScriptBridge.isInstalled
                )
                present(request: request, targets: visibleTargets)
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
        targets: [BrowserLaunchTarget]
    ) {
        let store = BrowserPickerStore(
            destination: request.destination,
            targets: targets,
            pickerShortcuts: dependencies.preferencesStore.pickerShortcuts
        )
        presentedStore = store

        let panel = panelBuilder(
            store,
            { [weak self] target, remembersSelection in
                self?.select(
                    target,
                    remembersSelection: remembersSelection
                )
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
        _ target: BrowserLaunchTarget,
        remembersSelection: Bool
    ) {
        guard launchTask == nil else {
            return
        }

        guard let request else {
            finishCurrentRequest()
            return
        }

        let ruleIntent = remembersSelection
            ? ExactHostRoutingRule(
                host: request.destination.url.host() ?? "",
                targetIdentifier: target.id
            )
            : nil

        launch(
            request: request,
            target: target,
            ruleIntent: ruleIntent
        )
    }

    private func launch(
        request: RoutingRequest,
        target: BrowserLaunchTarget,
        ruleIntent: ExactHostRoutingRule?
    ) {
        guard launchTask == nil else {
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
                    with: target
                )

                guard
                    !Task.isCancelled,
                    self.request?.id == request.id
                else {
                    launchTask = nil
                    return
                }

                if let ruleIntent {
                    dependencies.preferencesStore.setExactHostRoutingRule(
                        for: request.destination,
                        targetIdentifier: ruleIntent.targetIdentifier
                    )
                }
            } catch {
                if self.request?.id == request.id {
                    record(error)
                }
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
