import Foundation
@testable import Katabro
import Testing

@MainActor
@Suite("Login item client")
struct LoginItemClientTests {
    @Test("updates registration and refreshes system status")
    func updatesRegistration() {
        var status = LoginItemClient.Status.disabled
        var updates: [Bool] = []
        let client = LoginItemClient(
            statusProvider: {
                status
            },
            updateHandler: { enabled in
                updates.append(enabled)
                status = enabled ? .enabled : .disabled
            }
        )

        client.update(
            enabled: true
        )

        #expect(updates == [true])
        #expect(client.status == .enabled)
        #expect(client.isEnabled)
        #expect(client.lastError == nil)
    }

    @Test("surfaces registration errors and retains reported status")
    func reportsRegistrationError() {
        let client = LoginItemClient(
            statusProvider: {
                .disabled
            },
            updateHandler: { _ in
                throw LoginItemTestError.expected
            }
        )

        client.update(
            enabled: true
        )

        #expect(client.status == .disabled)
        #expect(!client.isEnabled)
        #expect(client.lastError == "expected")
    }

    @Test("treats pending user approval as requested but not fully enabled")
    func reportsRequiredApproval() {
        let client = LoginItemClient(
            statusProvider: {
                .requiresApproval
            },
            updateHandler: { _ in }
        )

        #expect(client.isEnabled)
        #expect(client.statusDescription.contains("System Settings"))
    }
}

private enum LoginItemTestError: LocalizedError {
    case expected

    var errorDescription: String? {
        "expected"
    }
}
