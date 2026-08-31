import AppKit
@testable import Katabro
import Testing

@MainActor
@Suite("Menu bar presentation state")
struct MenuBarPresentationStateTests {
    @Test("shortcut converts to an AppKit key equivalent and modifier mask")
    func convertsShortcut() throws {
        let shortcut = GlobalShortcut(
            keyCode: 8,
            displayKey: "C",
            modifiers: [.command, .option, .control, .shift]
        )
        let keyEquivalent = try #require(MenuBarKeyEquivalent(shortcut: shortcut))

        #expect(keyEquivalent.key == "c")
        #expect(keyEquivalent.modifiers == [.command, .option, .control, .shift])
        #expect(MenuBarKeyEquivalent(shortcut: GlobalShortcut(
            keyCode: 8,
            displayKey: "CC",
            modifiers: [.command, .option]
        )) == nil)
    }

    @Test("connection installs one enabled hidden shortcut item")
    func installsHiddenShortcutItem() throws {
        let fixture = MenuPresentationFixture()
        let item = try fixture.shortcutItem()

        #expect(item.isHidden)
        #expect(item.isEnabled)
        #expect(item.allowsKeyEquivalentWhenHidden)
        #expect(item.title.isEmpty)
        #expect(item.keyEquivalent == "k")
        #expect(item.keyEquivalentModifierMask == [.command, .option])
    }

    @Test("fallback requests one-way presentation without queued work")
    func fallbackRequestsPresentation() {
        let state = MenuBarPresentationState(
            notificationCenter: NotificationCenter()
        ) { 1 }

        state.toggle(eventTime: 1)
        #expect(state.isPresented)

        state.isPresented = false
        #expect(!state.isPresented)
    }

    @Test("first event before tracking begins opens exactly once")
    func opensBeforeTrackingBegins() {
        let fixture = MenuPresentationFixture()

        fixture.toggle(at: 9)

        #expect(fixture.actions.openCount == 1)
        #expect(fixture.actions.closeCount == 0)
        #expect(!fixture.state.isPresented)
    }

    @Test(arguments: [10.0, 20.0])
    func activeTrackingBoundsCloseInclusively(eventTime: TimeInterval) {
        let fixture = MenuPresentationFixture()
        fixture.begin(at: 10)
        fixture.clock.now = 20

        fixture.toggle(at: eventTime)

        #expect(fixture.actions.openCount == 0)
        #expect(fixture.actions.closeCount == 1)
    }

    @Test("delayed event from a completed interval does nothing")
    func suppressesDelayedCompletedIntervalEvent() {
        let fixture = MenuPresentationFixture()
        fixture.begin(at: 10)
        fixture.end(at: 20)

        fixture.toggle(at: 15)

        #expect(fixture.actions.openCount == 0)
        #expect(fixture.actions.closeCount == 0)
    }

    @Test("three queued events in one completed interval all do nothing")
    func suppressesEveryQueuedCompletedIntervalEvent() {
        let fixture = MenuPresentationFixture()
        fixture.begin(at: 10)
        fixture.end(at: 20)

        for eventTime in [10.0, 15.0, 20.0] {
            fixture.toggle(at: eventTime)
        }

        #expect(fixture.actions.openCount == 0)
        #expect(fixture.actions.closeCount == 0)
    }

    @Test("next event after a completed interval opens once")
    func opensAfterCompletedInterval() {
        let fixture = MenuPresentationFixture()
        fixture.begin(at: 10)
        fixture.end(at: 20)

        fixture.toggle(at: 21)

        #expect(fixture.actions.openCount == 1)
        #expect(fixture.actions.closeCount == 0)
    }

    @Test("ordinary native dismissal performs no action itself")
    func nativeDismissalDoesNotPerformAnAction() {
        let fixture = MenuPresentationFixture()

        fixture.begin(at: 10)
        fixture.end(at: 20)

        #expect(fixture.actions.openCount == 0)
        #expect(fixture.actions.closeCount == 0)
        #expect(fixture.lifecycle.events == ["begin", "end"])
    }

    @Test("notifications from another menu are ignored")
    func ignoresAnotherMenu() {
        let fixture = MenuPresentationFixture()
        let otherMenu = NSMenu()

        fixture.clock.now = 10
        fixture.center.post(name: NSMenu.didBeginTrackingNotification, object: otherMenu)
        fixture.clock.now = 20
        fixture.center.post(name: NSMenu.didEndTrackingNotification, object: otherMenu)
        fixture.toggle(at: 15)

        #expect(fixture.actions.openCount == 1)
        #expect(fixture.actions.closeCount == 0)
    }

    @Test("same-menu reconnect updates actions without duplicate observers")
    func reconnectsSameMenuIdempotently() throws {
        let fixture = MenuPresentationFixture()
        let replacementActions = MenuPresentationActionsFake()
        let replacementLifecycle = MenuTrackingLifecycleFake()
        let originalItem = try fixture.shortcutItem()
        fixture.menu.removeItem(originalItem)

        replacementActions.connect(
            state: fixture.state,
            menu: fixture.menu,
            onTrackingBegin: replacementLifecycle.begin,
            onTrackingEnd: replacementLifecycle.end
        ) { fixture.shortcutProvider.shortcut }
        let reconnectedItem = try fixture.shortcutItem()
        fixture.begin(at: 10)
        fixture.clock.now = 20
        fixture.toggle(at: 15)
        fixture.end(at: 20)

        #expect(reconnectedItem === originalItem)
        #expect(fixture.menu.items.count == 1)
        #expect(fixture.lifecycle.events.isEmpty)
        #expect(replacementLifecycle.events == ["begin", "end"])
        #expect(fixture.actions.openCount == 0)
        #expect(fixture.actions.closeCount == 0)
        #expect(replacementActions.openCount == 0)
        #expect(replacementActions.closeCount == 1)
    }

    @Test("begin tracking refreshes a changed registered shortcut")
    func refreshesShortcutAtTrackingBegin() throws {
        let fixture = MenuPresentationFixture()
        let item = try fixture.shortcutItem()
        fixture.shortcutProvider.shortcut = GlobalShortcut(
            keyCode: 8,
            displayKey: "C",
            modifiers: [.control, .shift]
        )

        #expect(item.keyEquivalent == "k")
        fixture.begin(at: 10)

        #expect(item.keyEquivalent == "c")
        #expect(item.keyEquivalentModifierMask == [.control, .shift])
    }

    @Test("begin restores the same hidden item after a SwiftUI menu rebuild")
    func restoresRemovedShortcutItemAtTrackingBegin() throws {
        let fixture = MenuPresentationFixture()
        let item = try fixture.shortcutItem()
        let menu = fixture.menu
        var wasRestoredBeforeBeginAction = false
        fixture.shortcutProvider.shortcut = GlobalShortcut(
            keyCode: 8,
            displayKey: "C",
            modifiers: [.control, .shift]
        )
        fixture.lifecycle.onBegin = {
            wasRestoredBeforeBeginAction = item.menu === menu
                && menu.items.filter { $0 === item }.count == 1
                && item.keyEquivalent == "c"
                && item.keyEquivalentModifierMask == [.control, .shift]
        }
        menu.removeItem(item)

        fixture.begin(at: 10)
        fixture.begin(at: 11)

        #expect(wasRestoredBeforeBeginAction)
        #expect(menu.items.count == 1)
        #expect(menu.items.first === item)
        #expect(item.isHidden)
        #expect(item.isEnabled)
        #expect(item.allowsKeyEquivalentWhenHidden)
        #expect(fixture.lifecycle.events == ["begin"])
        fixture.end(at: 20)
    }

    @Test("begin moves the same hidden item back from another menu")
    func restoresShortcutItemFromAnotherMenu() throws {
        let fixture = MenuPresentationFixture()
        let item = try fixture.shortcutItem()
        let otherMenu = NSMenu()
        fixture.menu.removeItem(item)
        otherMenu.addItem(item)

        fixture.begin(at: 10)

        #expect(otherMenu.items.isEmpty)
        #expect(fixture.menu.items.count == 1)
        #expect(fixture.menu.items.first === item)
        #expect(fixture.lifecycle.events == ["begin"])
        fixture.end(at: 20)
    }

    @Test("begin configures the item and records tracking before suspension")
    func ordersTrackingBegin() throws {
        let fixture = MenuPresentationFixture()
        let item = try fixture.shortcutItem()
        let state = fixture.state
        let actions = fixture.actions
        fixture.shortcutProvider.shortcut = GlobalShortcut(
            keyCode: 8,
            displayKey: "C",
            modifiers: [.control, .shift]
        )
        fixture.lifecycle.onBegin = {
            #expect(item.keyEquivalent == "c")
            state.toggle(eventTime: 10)
        }

        fixture.begin(at: 10)

        #expect(fixture.lifecycle.events == ["begin"])
        #expect(actions.openCount == 0)
        #expect(actions.closeCount == 1)
    }

    @Test("end completes the interval before resumption")
    func ordersTrackingEnd() {
        let fixture = MenuPresentationFixture()
        let state = fixture.state
        fixture.lifecycle.onEnd = {
            state.toggle(eventTime: 15)
        }
        fixture.begin(at: 10)

        fixture.end(at: 20)

        #expect(fixture.lifecycle.events == ["begin", "end"])
        #expect(fixture.actions.openCount == 0)
        #expect(fixture.actions.closeCount == 0)
    }

    @Test("begin tracking clears the shortcut when registration is disabled")
    func clearsDisabledShortcutAtTrackingBegin() throws {
        let fixture = MenuPresentationFixture()
        let item = try fixture.shortcutItem()
        fixture.shortcutProvider.shortcut = nil

        fixture.begin(at: 10)

        #expect(item.keyEquivalent.isEmpty)
        #expect(item.keyEquivalentModifierMask.isEmpty)
        #expect(item.isHidden)
        #expect(item.isEnabled)
    }

    @Test("hidden shortcut target invokes exactly one close action")
    func hiddenShortcutClosesOnce() throws {
        let fixture = MenuPresentationFixture()
        let item = try fixture.shortcutItem()
        let action = try #require(item.action)
        let target = try #require(item.target)
        fixture.begin(at: 10)

        #expect(NSApplication.shared.sendAction(action, to: target, from: item))
        fixture.end(at: 20)
        #expect(fixture.actions.openCount == 0)
        #expect(fixture.actions.closeCount == 1)
        #expect(fixture.lifecycle.events == ["begin", "end"])
    }

    @Test("replacement removes old observers and clears interval state")
    func replacesConnectedMenu() throws {
        let fixture = MenuPresentationFixture()
        let replacementMenu = NSMenu()
        let replacementActions = MenuPresentationActionsFake()
        let replacementLifecycle = MenuTrackingLifecycleFake()
        let oldItem = try fixture.shortcutItem()
        fixture.begin(at: 10)

        replacementActions.connect(
            state: fixture.state,
            menu: replacementMenu,
            onTrackingBegin: replacementLifecycle.begin,
            onTrackingEnd: replacementLifecycle.end
        ) { fixture.shortcutProvider.shortcut }
        let replacementItem = try #require(replacementMenu.items.first)
        fixture.clock.now = 30
        fixture.center.post(name: NSMenu.didBeginTrackingNotification, object: fixture.menu)
        fixture.toggle(at: 15)

        #expect(fixture.menu.items.isEmpty)
        #expect(oldItem.target == nil)
        #expect(replacementMenu.items.count == 1)
        #expect(replacementItem !== oldItem)
        #expect(fixture.lifecycle.events == ["begin", "end"])
        #expect(replacementLifecycle.events.isEmpty)
        #expect(fixture.actions.openCount == 0)
        #expect(fixture.actions.closeCount == 0)
        #expect(replacementActions.openCount == 1)
        #expect(replacementActions.closeCount == 0)
    }

    @Test("disconnect removes observers and clears interval state idempotently")
    func disconnectsIdempotently() throws {
        let fixture = MenuPresentationFixture()
        let item = try fixture.shortcutItem()
        fixture.begin(at: 10)

        fixture.state.disconnect()
        fixture.state.disconnect()
        fixture.begin(at: 30)
        fixture.end(at: 40)
        fixture.toggle(at: 15)

        #expect(fixture.menu.items.isEmpty)
        #expect(item.target == nil)
        #expect(item.keyEquivalent.isEmpty)
        #expect(fixture.lifecycle.events == ["begin", "end"])
        #expect(fixture.state.isPresented)
        #expect(fixture.actions.openCount == 0)
        #expect(fixture.actions.closeCount == 0)
    }
}

@MainActor
struct MenuPresentationFixture {
    let center: NotificationCenter
    let clock: EventTimeClockFake
    let repairScheduler: MenuTrackingRepairSchedulerFake
    let state: MenuBarPresentationState
    let menu: NSMenu
    let actions: MenuPresentationActionsFake
    let shortcutProvider: MenuShortcutProviderFake
    let lifecycle: MenuTrackingLifecycleFake

    init(shortcut: GlobalShortcut? = .showKatabroMenuDefault) {
        let center = NotificationCenter()
        let clock = EventTimeClockFake()
        let repairScheduler = MenuTrackingRepairSchedulerFake()
        let menu = NSMenu()
        let actions = MenuPresentationActionsFake()
        let shortcutProvider = MenuShortcutProviderFake(shortcut: shortcut)
        let lifecycle = MenuTrackingLifecycleFake()
        self.center = center
        self.clock = clock
        self.repairScheduler = repairScheduler
        state = MenuBarPresentationState(
            notificationCenter: center,
            trackingRepairScheduler: repairScheduler
        ) { clock.now }
        self.menu = menu
        self.actions = actions
        self.shortcutProvider = shortcutProvider
        self.lifecycle = lifecycle
        actions.connect(
            state: state,
            menu: menu,
            onTrackingBegin: lifecycle.begin,
            onTrackingEnd: lifecycle.end
        ) { shortcutProvider.shortcut }
    }

    func begin(at eventTime: TimeInterval) {
        clock.now = eventTime
        center.post(name: NSMenu.didBeginTrackingNotification, object: menu)
    }

    func end(at eventTime: TimeInterval) {
        clock.now = eventTime
        center.post(name: NSMenu.didEndTrackingNotification, object: menu)
    }

    func toggle(at eventTime: TimeInterval) {
        state.toggle(eventTime: eventTime)
    }

    func addVisibleItem(title: String) {
        menu.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
        center.post(name: NSMenu.didAddItemNotification, object: menu)
    }

    func shortcutItem() throws -> NSMenuItem {
        #expect(menu.items.count == 1)
        return try #require(menu.items.first)
    }
}

@MainActor
final class MenuTrackingRepairSchedulerFake: MenuTrackingRepairScheduling {
    private var actions: [@MainActor () -> Void] = []
    private(set) var scheduleCount = 0
    var pendingCount: Int {
        actions.count
    }

    func schedule(_ action: @escaping @MainActor () -> Void) {
        scheduleCount += 1
        actions.append(action)
    }

    func runNext() {
        guard !actions.isEmpty else { return }
        actions.removeFirst()()
    }
}

@MainActor
final class EventTimeClockFake {
    var now: TimeInterval = 0
}

@MainActor
final class MenuShortcutProviderFake {
    var shortcut: GlobalShortcut?

    init(shortcut: GlobalShortcut?) {
        self.shortcut = shortcut
    }
}

@MainActor
final class MenuTrackingLifecycleFake {
    private(set) var events: [String] = []
    var onBegin: @MainActor () -> Void = {}
    var onEnd: @MainActor () -> Void = {}

    func begin() {
        events.append("begin")
        onBegin()
    }

    func end() {
        events.append("end")
        onEnd()
    }
}

@MainActor
final class MenuPresentationActionsFake {
    private(set) var openCount = 0
    private(set) var closeCount = 0

    func connect(
        state: MenuBarPresentationState,
        menu: NSMenu,
        onTrackingBegin: @escaping MenuBarPresentationState.PresentationAction = {},
        onTrackingEnd: @escaping MenuBarPresentationState.PresentationAction = {},
        shortcutProvider: @escaping MenuBarPresentationState.ShortcutProvider = { nil }
    ) {
        state.connect(
            menu: menu,
            open: { self.openCount += 1 },
            close: { self.closeCount += 1 },
            shortcutProvider: shortcutProvider,
            onTrackingBegin: onTrackingBegin,
            onTrackingEnd: onTrackingEnd
        )
    }
}
