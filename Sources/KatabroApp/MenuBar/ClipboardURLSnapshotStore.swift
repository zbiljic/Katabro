import Foundation
import Observation

@MainActor
@Observable
final class ClipboardURLSnapshotStore {
    @ObservationIgnored private let clipboardURLClient: ClipboardURLClient
    @ObservationIgnored private var lastChangeCount: Int?
    @ObservationIgnored private var refreshTimer: Timer?

    private(set) var url: URL?

    var displayText: String? {
        guard let absoluteString = url?.absoluteString else {
            return nil
        }

        return Self.truncatedDisplayText(
            absoluteString
        )
    }

    init(
        clipboardURLClient: ClipboardURLClient
    ) {
        self.clipboardURLClient = clipboardURLClient
    }

    func refresh() {
        refresh(
            changeCount: clipboardURLClient.changeCount()
        )
    }

    func refreshIfNeeded() {
        let changeCount = clipboardURLClient.changeCount()
        guard changeCount != lastChangeCount else {
            return
        }

        refresh(
            changeCount: changeCount
        )
    }

    func startMonitoring() {
        guard refreshTimer == nil else {
            return
        }

        refresh()

        let timer = Timer(
            timeInterval: 1,
            repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshIfNeeded()
            }
        }
        RunLoop.main.add(
            timer,
            forMode: .default
        )
        refreshTimer = timer
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refresh(
        changeCount: Int
    ) {
        lastChangeCount = changeCount
        url = clipboardURLClient.currentURL()
    }

    private static func truncatedDisplayText(
        _ value: String
    ) -> String {
        let maximumCharacterCount = 56
        guard value.count > maximumCharacterCount else {
            return value
        }

        let visibleCharacterCount = maximumCharacterCount - 1
        let prefixCharacterCount = visibleCharacterCount / 2
        let suffixCharacterCount = visibleCharacterCount - prefixCharacterCount

        return String(value.prefix(prefixCharacterCount))
            + "…"
            + String(value.suffix(suffixCharacterCount))
    }
}
