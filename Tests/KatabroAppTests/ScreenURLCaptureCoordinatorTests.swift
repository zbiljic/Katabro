import CoreGraphics
import Foundation
@testable import Katabro
import KatabroCore
import Testing

// swiftlint:disable force_unwrapping multiline_arguments

@MainActor
@Suite("Screen URL capture coordinator")
struct ScreenURLCaptureCoordinatorTests {
    @Test("the production panel keeps room for several results after loading")
    func panelKeepsResultHeight() throws {
        let store = ScreenURLPickerStore(state: .loading)
        let panel = ScreenURLPickerPanel(
            rootView: ScreenURLPickerView(
                store: store,
                onSelect: { _ in },
                onCancel: {}
            )
        )
        defer { panel.close() }

        #expect(panel.contentLayoutRect.size == ScreenURLPickerPanel.contentSize)
        try store.replaceState(with: .results([
            detected("https://one.example"),
            detected("https://two.example"),
            detected("https://three.example"),
        ]))
        panel.contentView?.layoutSubtreeIfNeeded()
        #expect(panel.contentLayoutRect.size == ScreenURLPickerPanel.contentSize)
        #expect(panel.contentViewController?.view.frame.height == ScreenURLPickerPanel.contentSize.height)
    }

    @Test("unavailable Vision presents without requesting access")
    func visionUnavailable() async {
        var requests = 0
        let capture = ScreenCaptureClient(
            authorizationStatus: { .notAuthorized },
            requestAuthorization: { requests += 1; return false },
            capture: { throw ScreenCaptureClientError.captureFailed }
        )
        let panel = PanelFake()
        let coordinator = ScreenURLCaptureCoordinator(
            captureClient: capture,
            recognitionClient: .unavailable,
            route: { _ in },
            panelBuilder: { _, _, _ in panel }
        )
        coordinator.capture()
        await coordinator.waitForPendingOperations()
        #expect(requests == 0)
        #expect(panel.presentCount == 1)
    }

    @Test("unauthorized capture presents guidance without requesting access")
    func permissionDenied() async {
        var requests = 0
        var captures = 0
        let capture = ScreenCaptureClient(
            authorizationStatus: { .notAuthorized }, requestAuthorization: { requests += 1; return false },
            capture: { captures += 1; return Self.image() }
        )
        let panel = PanelFake()
        let coordinator = makeCoordinator(capture: capture, recognition: successRecognition(), panel: panel)
        coordinator.capture()
        await coordinator.waitForPendingOperations()
        #expect(requests == 0)
        #expect(captures == 0)
        #expect(panel.store?.state == .permissionRequired)
    }

    @Test("authorized capture proceeds without requesting access")
    func authorizedCaptureWithoutRequest() async {
        var requests = 0
        var captures = 0
        let capture = ScreenCaptureClient(
            authorizationStatus: { .authorized },
            requestAuthorization: { requests += 1; return true },
            capture: { captures += 1; return Self.image() }
        )
        let panel = PanelFake()
        let coordinator = makeCoordinator(capture: capture, recognition: successRecognition(), panel: panel)
        coordinator.capture()
        await coordinator.waitForPendingOperations()
        #expect(requests == 0)
        #expect(captures == 1)
        #expect(panel.store?.state == .empty)
    }

    @Test("capture and recognition failures are presented")
    func failures() async {
        let panel = PanelFake()
        let capture = ScreenCaptureClient(
            authorizationStatus: { .authorized }, requestAuthorization: { true },
            capture: { throw ScreenCaptureClientError.captureFailed }
        )
        let coordinator = makeCoordinator(capture: capture, recognition: successRecognition(), panel: panel)
        coordinator.capture()
        await coordinator.waitForPendingOperations()
        #expect(panel.store?.state == .captureFailed)

        let recognitionFailure = VisionURLRecognitionClient(
            isAvailable: { true }, recognizeURLs: { _ in throw VisionURLRecognitionError.recognitionFailed }
        )
        let second = PanelFake()
        let succeedingCapture = ScreenCaptureClient(
            authorizationStatus: { .authorized }, requestAuthorization: { true }, capture: { Self.image() }
        )
        let secondCoordinator = makeCoordinator(
            capture: succeedingCapture,
            recognition: recognitionFailure,
            panel: second
        )
        secondCoordinator.capture()
        await secondCoordinator.waitForPendingOperations()
        #expect(second.store?.state == .captureFailed)
    }

    @Test("presents empty and ordered recognition results")
    func emptyAndOrderedResults() async throws {
        let capture = ScreenCaptureClient(
            authorizationStatus: { .authorized }, requestAuthorization: { true }, capture: { Self.image() }
        )
        let empty = PanelFake()
        let emptyCoordinator = makeCoordinator(
            capture: capture,
            recognition: .init(isAvailable: { true }, recognizeURLs: { _ in [] }),
            panel: empty
        )
        emptyCoordinator.capture()
        await emptyCoordinator.waitForPendingOperations()
        #expect(empty.store?.state == .empty)

        let values = try [detected("https://one.example"), detected("https://two.example")]
        let results = PanelFake()
        let coordinator = makeCoordinator(
            capture: capture,
            recognition: .init(isAvailable: { true }, recognizeURLs: { _ in values }), panel: results
        )
        coordinator.capture()
        await coordinator.waitForPendingOperations()
        #expect(results.store?.results == values)
    }

    @Test("routes individual and all URLs in exact order once")
    func selectionRoutingAndSuppression() async throws {
        let values = try [detected("https://one.example"), detected("https://two.example")]
        var routed: [String] = []
        let panel = PanelFake()
        let coordinator = ScreenURLCaptureCoordinator(
            captureClient: authorizedCapture(),
            recognitionClient: .init(isAvailable: { true }, recognizeURLs: { _ in values }),
            route: { routed.append($0.destination.url.absoluteString) },
            panelBuilder: panel.install
        )
        coordinator.capture()
        await coordinator.waitForPendingOperations()
        panel.select?(.url(1))
        panel.select?(.url(1))
        #expect(routed == ["https://two.example"])

        coordinator.capture()
        await coordinator.waitForPendingOperations()
        panel.select?(.all)
        panel.select?(.all)
        #expect(routed == ["https://two.example", "https://one.example", "https://two.example"])
    }

    @Test("ignores repeated capture while an operation is active")
    func repeatedCaptureSuppression() async {
        let gate = AsyncGate()
        let captureStarted = AsyncGate()
        var captures = 0
        let capture = ScreenCaptureClient(
            authorizationStatus: { .authorized }, requestAuthorization: { true },
            capture: {
                captures += 1
                await captureStarted.openGate()
                await gate.wait()
                return Self.image()
            }
        )
        let panel = PanelFake()
        let coordinator = makeCoordinator(capture: capture, recognition: successRecognition(), panel: panel)
        coordinator.capture()
        coordinator.capture()
        await captureStarted.wait()
        #expect(captures == 1)
        await gate.openGate()
        await coordinator.waitForPendingOperations()
    }

    @Test("cancellation prevents stale capture completion")
    func cancellationPreventsStaleCompletion() async {
        let gate = AsyncGate()
        let capture = ScreenCaptureClient(
            authorizationStatus: { .authorized }, requestAuthorization: { true },
            capture: { await gate.wait(); return Self.image() }
        )
        let panel = PanelFake()
        let coordinator = makeCoordinator(capture: capture, recognition: successRecognition(), panel: panel)
        coordinator.capture()
        coordinator.cancel()
        await gate.openGate()
        await coordinator.waitForPendingOperations()
        #expect(panel.presentCount == 0)
    }

    @Test("cancellation during recognition prevents stale result mutation")
    func cancellationDuringRecognition() async throws {
        let gate = AsyncGate()
        let result = try detected("https://stale.example")
        let recognition = VisionURLRecognitionClient(
            isAvailable: { true },
            recognizeURLs: { _ in
                await gate.wait()
                return [result]
            }
        )
        let panel = PanelFake()
        let coordinator = makeCoordinator(capture: authorizedCapture(), recognition: recognition, panel: panel)
        coordinator.capture()
        while panel.store?.state != .loading {
            await Task.yield()
        }
        coordinator.cancel()
        await gate.openGate()
        await coordinator.waitForPendingOperations()
        #expect(panel.closeCount == 1)
        #expect(panel.store?.results.isEmpty ?? true)
    }

    @Test("an old completion cannot mutate a replacement operation")
    func staleCompletionCannotMutateNewOperation() async throws {
        let oldGate = AsyncGate()
        let oldRecognitionStarted = AsyncGate()
        let oldFinished = AsyncGate()
        let oldResult = try detected("https://old.example")
        let newResult = try detected("https://new.example")
        var recognitionCount = 0
        let recognition = VisionURLRecognitionClient(
            isAvailable: { true },
            recognizeURLs: { _ in
                recognitionCount += 1
                if recognitionCount == 1 {
                    await oldRecognitionStarted.openGate()
                    await oldGate.wait()
                    await oldFinished.openGate()
                    return [oldResult]
                }
                return [newResult]
            }
        )
        let panel = PanelFake()
        let coordinator = makeCoordinator(capture: authorizedCapture(), recognition: recognition, panel: panel)
        coordinator.capture()
        await oldRecognitionStarted.wait()
        coordinator.cancel()
        coordinator.capture()
        await coordinator.waitForPendingOperations()
        await oldGate.openGate()
        await oldFinished.wait()
        #expect(panel.store?.results == [newResult])
    }

    private func makeCoordinator(
        capture: ScreenCaptureClient,
        recognition: VisionURLRecognitionClient,
        panel: PanelFake
    ) -> ScreenURLCaptureCoordinator {
        ScreenURLCaptureCoordinator(
            captureClient: capture,
            recognitionClient: recognition,
            route: { _ in },
            panelBuilder: panel.install
        )
    }

    private func authorizedCapture() -> ScreenCaptureClient {
        ScreenCaptureClient(
            authorizationStatus: { .authorized }, requestAuthorization: { true }, capture: { Self.image() }
        )
    }

    private func successRecognition() -> VisionURLRecognitionClient {
        .init(isAvailable: { true }, recognizeURLs: { _ in [] })
    }

    private func detected(_ value: String) throws -> DetectedURL {
        try DetectedURL(destination: IncomingURL(value))
    }

    private static func image() -> CGImage {
        CGImage(
            width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data([0, 0, 0, 255]) as CFData)!, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent
        )!
    }
}

@MainActor
private final class PanelFake: ScreenURLPickerPresenting {
    var presentCount = 0
    var closeCount = 0
    var store: ScreenURLPickerStore?
    var select: ((ScreenURLPickerStore.Selection) -> Void)?
    var cancel: (() -> Void)?
    var install: ScreenURLCaptureCoordinator.PanelBuilder {
        { store, select, cancel in
            self.store = store
            self.select = select
            self.cancel = cancel
            return self
        }
    }

    func presentNearPointer() {
        presentCount += 1
    }

    func close() {
        closeCount += 1
    }
}

actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if isOpen {
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func openGate() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}

// swiftlint:enable force_unwrapping multiline_arguments
