import KatabroCore

struct RoutingRequestQueue {
    private var requests: [RoutingRequest] = []

    var count: Int {
        requests.count
    }

    var isEmpty: Bool {
        requests.isEmpty
    }

    mutating func enqueue(
        _ request: RoutingRequest
    ) {
        requests.append(request)
    }

    mutating func dequeue() -> RoutingRequest? {
        guard !requests.isEmpty else {
            return nil
        }

        return requests.removeFirst()
    }

    mutating func removeAll() {
        requests.removeAll()
    }
}
