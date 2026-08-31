import AppKit
@testable import Katabro
import Testing

@MainActor
@Suite("Menu bar tracking repair")
struct MenuBarTrackingRepairTests {
    @Test("active SwiftUI rebuild restores one configured shortcut item")
    func restoresShortcutAfterActiveRebuild() throws {
        let fixture = MenuPresentationFixture()
        let item = try fixture.shortcutItem()
        fixture.begin(at: 10)
        fixture.shortcutProvider.shortcut = GlobalShortcut(
            keyCode: 8,
            displayKey: "C",
            modifiers: [.control, .shift]
        )

        fixture.menu.removeItem(item)
        fixture.addVisibleItem(title: "Settings")
        fixture.addVisibleItem(title: "Quit")

        #expect(item.menu == nil)
        #expect(fixture.repairScheduler.scheduleCount == 1)
        #expect(fixture.repairScheduler.pendingCount == 1)

        fixture.repairScheduler.runNext()

        #expect(item.menu === fixture.menu)
        #expect(fixture.menu.items.filter { $0 === item }.count == 1)
        #expect(item.keyEquivalent == "c")
        #expect(item.keyEquivalentModifierMask == [.control, .shift])
        #expect(item.isHidden)
        #expect(item.isEnabled)
        #expect(item.allowsKeyEquivalentWhenHidden)
        #expect(fixture.repairScheduler.pendingCount == 0)

        let action = try #require(item.action)
        let target = try #require(item.target)
        #expect(NSApplication.shared.sendAction(action, to: target, from: item))
        #expect(fixture.actions.closeCount == 1)

        fixture.addVisibleItem(title: "About")
        #expect(fixture.repairScheduler.scheduleCount == 1)
        fixture.end(at: 20)
    }

    @Test("tracking end invalidates a pending repair")
    func endInvalidatesPendingRepair() throws {
        let fixture = MenuPresentationFixture()
        let item = try fixture.shortcutItem()
        fixture.begin(at: 10)
        fixture.menu.removeItem(item)
        fixture.addVisibleItem(title: "Settings")

        fixture.end(at: 20)
        fixture.repairScheduler.runNext()

        #expect(item.menu == nil)
        #expect(!fixture.menu.items.contains { $0 === item })
        #expect(fixture.repairScheduler.pendingCount == 0)
        #expect(fixture.lifecycle.events == ["begin", "end"])
    }

    @Test("disconnect invalidates a pending repair")
    func disconnectInvalidatesPendingRepair() throws {
        let fixture = MenuPresentationFixture()
        let item = try fixture.shortcutItem()
        fixture.begin(at: 10)
        fixture.menu.removeItem(item)
        fixture.addVisibleItem(title: "Settings")

        fixture.state.disconnect()
        fixture.repairScheduler.runNext()

        #expect(item.menu == nil)
        #expect(item.target == nil)
        #expect(!fixture.menu.items.contains { $0 === item })
        #expect(fixture.repairScheduler.pendingCount == 0)
        #expect(fixture.lifecycle.events == ["begin", "end"])
    }
}
