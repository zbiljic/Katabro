import Foundation
import KatabroCore
import Observation

@MainActor
@Observable
final class RoutingDecisionLogStore {
    static let capacity = 50

    private(set) var entries: [RoutingDecisionLogEntry] = []

    func receive(
        _ request: RoutingRequest,
        at receivedAt: Date = Date()
    ) {
        guard !entries.contains(where: { $0.id == request.id }) else {
            return
        }

        entries.append(
            RoutingDecisionLogEntry(
                request: request,
                receivedAt: receivedAt
            )
        )

        if entries.count > Self.capacity {
            entries.removeFirst(entries.count - Self.capacity)
        }
    }

    func updateDecision(
        for requestID: UUID,
        to decision: RoutingDecisionLogEntry.Decision
    ) {
        guard let index = entries.firstIndex(where: { $0.id == requestID }) else {
            return
        }

        entries[index].decision = decision
    }

    func updateResult(
        for requestID: UUID,
        to result: RoutingDecisionLogEntry.Result
    ) {
        guard let index = entries.firstIndex(where: { $0.id == requestID }) else {
            return
        }

        entries[index].result = result
    }

    func finishIfPending(
        requestID: UUID
    ) {
        guard
            let index = entries.firstIndex(where: { $0.id == requestID }),
            entries[index].result == .pending
        else {
            return
        }

        entries[index].result = .cancelled
    }

    func clear() {
        entries.removeAll()
    }
}
