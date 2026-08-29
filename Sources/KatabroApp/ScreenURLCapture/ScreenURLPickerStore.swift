import Observation

// swiftlint:disable switch_case_alignment

@MainActor
@Observable
final class ScreenURLPickerStore {
    enum State: Equatable {
        case loading
        case results([DetectedURL])
        case empty
        case permissionRequired
        case captureFailed
        case visionUnavailable
    }

    enum Selection: Equatable { case url(Int); case all }

    private(set) var state: State
    private(set) var selection: Selection?

    init(state: State = .loading) {
        self.state = state
        selection = Self.initialSelection(for: state)
    }

    var results: [DetectedURL] {
        if case let .results(results) = state {
            results
        } else {
            []
        }
    }

    var supportsOpenAll: Bool {
        results.count >= 2
    }

    func replaceState(with state: State) {
        self.state = state
        selection = Self.initialSelection(for: state)
    }

    func select(index: Int) {
        guard results.indices.contains(index) else { return }
        selection = .url(index)
    }

    func selectOpenAll() {
        guard supportsOpenAll else { return }
        selection = .all
    }

    func moveSelection(by offset: Int) {
        let total = results.count + (supportsOpenAll ? 1 : 0)
        guard total > 0 else { selection = nil; return }
        let current: Int = switch selection { case let .url(index): index; case .all: results.count; case nil: 0 }
        let next = (current + offset % total + total) % total
        selection = next == results.count ? .all : .url(next)
    }

    private static func initialSelection(for state: State) -> Selection? {
        if case let .results(results) = state, !results.isEmpty {
            .url(0)
        } else {
            nil
        }
    }
}

// swiftlint:enable switch_case_alignment
