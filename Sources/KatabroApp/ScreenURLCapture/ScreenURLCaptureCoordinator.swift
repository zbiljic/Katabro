import Foundation
import KatabroCore

@MainActor
final class ScreenURLCaptureCoordinator {
    typealias PanelBuilder = @MainActor (
        ScreenURLPickerStore,
        @escaping (ScreenURLPickerStore.Selection) -> Void,
        @escaping () -> Void
    ) -> any ScreenURLPickerPresenting

    private let captureClient: ScreenCaptureClient
    private let recognitionClient: VisionURLRecognitionClient
    private let route: (RoutingRequest) -> Void
    private let panelBuilder: PanelBuilder
    private var operation: UUID?
    private var task: Task<Void, Never>?
    private var panel: (any ScreenURLPickerPresenting)?
    private var store: ScreenURLPickerStore?

    init(
        captureClient: ScreenCaptureClient,
        recognitionClient: VisionURLRecognitionClient,
        route: @escaping (RoutingRequest) -> Void,
        panelBuilder: PanelBuilder? = nil
    ) {
        self.captureClient = captureClient
        self.recognitionClient = recognitionClient
        self.route = route
        self.panelBuilder = panelBuilder ?? { store, select, cancel in
            ScreenURLPickerPanel(
                rootView: ScreenURLPickerView(
                    store: store,
                    onSelect: select,
                    onCancel: cancel,
                    onOpenScreenRecordingSettings: captureClient.openSystemSettings
                ),
                onResign: cancel
            )
        }
    }

    convenience init(dependencies: AppDependencies, pickerCoordinator: BrowserPickerCoordinator) {
        self.init(
            captureClient: dependencies.screenCaptureClient,
            recognitionClient: dependencies.visionURLRecognitionClient,
            route: pickerCoordinator.route
        )
    }

    func capture() {
        guard task == nil, panel == nil else { return }
        guard recognitionClient.isAvailable() else { present(state: .visionUnavailable); return }
        guard captureClient.authorizationStatus() == .authorized else { present(state: .permissionRequired); return }
        let identifier = UUID()
        operation = identifier
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let image = try await captureClient.capture()
                guard !Task.isCancelled, operation == identifier else { return }
                present(state: .loading)
                let results = try await recognitionClient.recognizeURLs(image)
                guard !Task.isCancelled, operation == identifier else { return }
                store?.replaceState(with: results.isEmpty ? .empty : .results(results))
            } catch {
                guard !Task.isCancelled, operation == identifier else { return }
                present(state: .captureFailed)
            }
            if operation == identifier {
                task = nil
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        operation = nil
        let panelToClose = panel
        panel = nil
        store = nil
        panelToClose?.close()
    }

    func waitForPendingOperations() async {
        await task?.value
    }

    private func present(state: ScreenURLPickerStore.State) {
        if let store {
            store.replaceState(with: state); return
        }
        let store = ScreenURLPickerStore(state: state)
        self.store = store
        panel = panelBuilder(
            store,
            { [weak self] selection in self?.activate(selection) },
            { [weak self] in self?.cancel() }
        )
        panel?.presentNearPointer()
    }

    private func activate(_ selection: ScreenURLPickerStore.Selection) {
        guard let store else { return }
        let destinations: [DetectedURL] = switch selection {
        case let .url(index): store.results.indices.contains(index) ? [store.results[index]] : []
        case .all: store.supportsOpenAll ? store.results : []
        }
        guard !destinations.isEmpty else { return }
        cancel()
        for detected in destinations {
            route(RoutingRequest(destination: detected.destination, source: .screenCapture))
        }
    }
}
