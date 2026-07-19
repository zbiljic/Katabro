@testable import Katabro
import KatabroCore
import Testing

@Suite("Routing request queue")
struct RoutingRequestQueueTests {
    @Test("dequeues requests in first-in first-out order")
    func firstInFirstOut() throws {
        let requests = try [
            RoutingRequest(
                destination: IncomingURL("https://one.example"),
                source: .system
            ),
            RoutingRequest(
                destination: IncomingURL("https://two.example"),
                source: .customURL
            ),
            RoutingRequest(
                destination: IncomingURL("https://three.example"),
                source: .commandLine
            ),
        ]
        var queue = RoutingRequestQueue()

        for request in requests {
            queue.enqueue(request)
        }

        #expect(queue.count == 3)
        #expect(queue.dequeue() == requests[0])
        #expect(queue.dequeue() == requests[1])
        #expect(queue.dequeue() == requests[2])
        #expect(queue.dequeue() == nil)
        #expect(queue.isEmpty)
    }

    @Test("removes all pending requests")
    func removesAll() throws {
        var queue = RoutingRequestQueue()
        try queue.enqueue(
            RoutingRequest(
                destination: IncomingURL("https://example.com"),
                source: .system
            )
        )

        queue.removeAll()

        #expect(queue.isEmpty)
    }
}
