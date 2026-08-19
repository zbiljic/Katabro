import AppKit
import KatabroCore

// Menu scheduling and routing lifecycle intentionally remain together.
// swiftlint:disable file_length

@MainActor
protocol MenuActionScheduling {
    func schedule(
        _ action: @escaping @MainActor () -> Void
    )
}

@MainActor
final class MenuTrackingActionScheduler: NSObject, MenuActionScheduling {
    private var pendingCompletion: (@MainActor () -> Void)?

    func schedule(
        _ action: @escaping @MainActor () -> Void
    ) {
        NotificationCenter.default.removeObserver(
            self,
            name: NSMenu.didEndTrackingNotification,
            object: nil
        )
        pendingCompletion = action
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuDidEndTracking(_:)),
            name: NSMenu.didEndTrackingNotification,
            object: nil
        )
    }

    @objc
    private func menuDidEndTracking(
        _: Notification
    ) {
        NotificationCenter.default.removeObserver(
            self,
            name: NSMenu.didEndTrackingNotification,
            object: nil
        )

        let completion = pendingCompletion
        pendingCompletion = nil
        completion?()
    }
}

@MainActor
struct ImmediateMenuActionScheduler: MenuActionScheduling {
    func schedule(
        _ action: @escaping @MainActor () -> Void
    ) {
        action()
    }
}

@MainActor
final class BrowserPickerCoordinator: NSObject { // swiftlint:disable:this type_body_length

    typealias PanelBuilder = @MainActor (
        _ store: BrowserPickerStore,
        _ onSelect: @escaping (BrowserLaunchTarget, Bool) -> Void,
        _ onCopyLink: @escaping () -> Void,
        _ onCancel: @escaping () -> Void
    ) -> any BrowserPickerPresenting

    private let dependencies: AppDependencies
    private let menuActionScheduler: any MenuActionScheduling
    private let panelBuilder: PanelBuilder
    private var launchTask: Task<Void, Never>?
    private var panel: (any BrowserPickerPresenting)?
    private var presentsPreview = false
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
        menuActionScheduler: any MenuActionScheduling = MenuTrackingActionScheduler(),
        panelBuilder: @escaping PanelBuilder = { store, onSelect, onCopyLink, onCancel in
            let view = BrowserPickerView(
                store: store,
                onSelect: onSelect,
                onCopyLink: onCopyLink,
                onCancel: onCancel
            )

            return BrowserPickerPanel(
                rootView: view,
                layout: BrowserPickerLayout(
                    preferences: store.pickerPreferences,
                    targetCount: store.targets.count,
                    includesRememberFooter: store.canRememberSelection
                )
            )
        }
    ) {
        self.dependencies = dependencies
        self.menuActionScheduler = menuActionScheduler
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

    func openClipboardURL() {
        let url = dependencies.clipboardURLClient.currentURL()
        menuActionScheduler.schedule { [weak self] in
            self?.applyClipboardURL(url)
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

    private func applyClipboardURL(
        _ url: URL?
    ) {
        if let url {
            handle(url)
        } else {
            record(ClipboardURLReadError.noRoutableURL)
        }
    }

    func cancel() {
        finishCurrentRequest()
    }

    func preview() {
        guard request == nil else {
            return
        }

        do {
            let request = try RoutingRequest(
                destination: IncomingURL("https://example.com"),
                source: .system
            )
            startPreview(request)
        } catch {
            record(error)
        }
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
                let orderedBrowsers = try await orderedBrowsers(
                    for: request.destination
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

                refreshTargetSources(for: orderedBrowsers)
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

                let visibleTargets = visibleTargets(for: orderedBrowsers)
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

    private func startPreview(
        _ request: RoutingRequest
    ) {
        self.request = request
        presentsPreview = true
        lastError = nil

        routingTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let orderedBrowsers = try await orderedBrowsers(
                    for: request.destination
                )
                guard
                    !Task.isCancelled,
                    self.request?.id == request.id,
                    presentsPreview
                else {
                    return
                }

                refreshTargetSources(for: orderedBrowsers)
                let targets = visibleTargets(for: orderedBrowsers)

                guard
                    !Task.isCancelled,
                    self.request?.id == request.id,
                    presentsPreview
                else {
                    return
                }

                routingTask = nil
                present(request: request, targets: targets)
            } catch {
                guard
                    !Task.isCancelled,
                    self.request?.id == request.id,
                    presentsPreview
                else {
                    return
                }

                record(error)
                routingTask = nil
                finishCurrentRequest(id: request.id)
            }
        }
    }

    private func orderedBrowsers(
        for destination: IncomingURL
    ) async throws -> [BrowserApplication] {
        let discoveredBrowsers = try await dependencies.browserDiscovery.browsers(
            for: destination
        )
        return dependencies.preferencesStore.orderedBrowsers(discoveredBrowsers)
    }

    private func refreshTargetSources(
        for orderedBrowsers: [BrowserApplication]
    ) {
        dependencies.userScriptBridge.refresh()
        for browser in orderedBrowsers {
            dependencies.browserProfileStore.refresh(for: browser)
        }
    }

    private func visibleTargets(
        for orderedBrowsers: [BrowserApplication]
    ) -> [BrowserLaunchTarget] {
        let visibleBrowsers = dependencies.preferencesStore.effectiveVisibleBrowsers(
            orderedBrowsers
        )
        return dependencies.browserProfileStore.targets(
            for: visibleBrowsers,
            includesArgumentTargets: dependencies.userScriptBridge.isInstalled
        )
    }

    private func present(
        request: RoutingRequest,
        targets: [BrowserLaunchTarget]
    ) {
        let store = BrowserPickerStore(
            destination: request.destination,
            targets: targets,
            pickerShortcuts: dependencies.preferencesStore.pickerShortcuts,
            pickerPreferences: dependencies.preferencesStore.pickerPreferences
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
                self?.copy(request: request)
            },
            { [weak self] in
                self?.cancel()
            }
        )

        panel.delegate = self
        self.panel = panel
        panel.presentNearPointer()
    }

    private func copy(
        request: RoutingRequest
    ) {
        guard self.request?.id == request.id else {
            return
        }

        do {
            try dependencies.clipboardURLClient.copy(request.destination.url)
            finishCurrentRequest(id: request.id)
        } catch {
            record(error)
        }
    }

    private func select(
        _ target: BrowserLaunchTarget,
        remembersSelection: Bool
    ) {
        guard !presentsPreview else {
            finishCurrentRequest()
            return
        }

        guard launchTask == nil else {
            return
        }

        guard let request else {
            finishCurrentRequest()
            return
        }

        let ruleIntent = remembersSelection
            && (request.destination.scheme == .http || request.destination.scheme == .https)
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
        presentsPreview = false

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
