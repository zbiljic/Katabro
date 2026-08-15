import KatabroCore

@MainActor
struct RoutingDecisionClient {
    enum Decision: Equatable, Sendable {
        case ask
        case open(targetIdentifier: String)
    }

    typealias ResolveHandler = @MainActor (
        _ request: RoutingRequest,
        _ rules: [ExactHostRoutingRule]
    ) async -> Decision

    private let resolve: ResolveHandler

    init(
        resolve: @escaping ResolveHandler
    ) {
        self.resolve = resolve
    }

    func decision(
        for request: RoutingRequest,
        rules: [ExactHostRoutingRule]
    ) async -> Decision {
        await resolve(request, rules)
    }

    static let exactHostRules = Self { request, rules in
        guard let rule = rules.first(where: { $0.matches(request.destination) }) else {
            return .ask
        }

        return .open(targetIdentifier: rule.targetIdentifier)
    }
}
