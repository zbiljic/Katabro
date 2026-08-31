import AppKit
import Carbon
import Observation

struct MenuBarKeyEquivalent: Equatable {
    let key: String
    let modifiers: NSEvent.ModifierFlags

    init?(shortcut: GlobalShortcut) {
        guard
            shortcut.displayKey.count == 1,
            let character = shortcut.displayKey.lowercased().first
        else { return nil }
        key = String(character)

        var modifiers: NSEvent.ModifierFlags = []
        if shortcut.modifiers.contains(.command) {
            modifiers.insert(.command)
        }
        if shortcut.modifiers.contains(.option) {
            modifiers.insert(.option)
        }
        if shortcut.modifiers.contains(.control) {
            modifiers.insert(.control)
        }
        if shortcut.modifiers.contains(.shift) {
            modifiers.insert(.shift)
        }
        self.modifiers = modifiers
    }
}

@MainActor
protocol MenuTrackingRepairScheduling {
    func schedule(_ action: @escaping @MainActor () -> Void)
}

@MainActor
struct MenuTrackingRunLoopRepairScheduler: MenuTrackingRepairScheduling {
    func schedule(_ action: @escaping @MainActor () -> Void) {
        RunLoop.main.perform(inModes: [.eventTracking]) {
            MainActor.assumeIsolated {
                action()
            }
        }
    }
}

@MainActor
@Observable
final class MenuBarPresentationState {
    typealias PresentationAction = @MainActor () -> Void
    typealias EventTimeClock = @MainActor () -> TimeInterval
    typealias ShortcutProvider = @MainActor () -> GlobalShortcut?

    var isPresented = false

    @ObservationIgnored private let notificationCenter: NotificationCenter
    @ObservationIgnored private let trackingRepairScheduler: any MenuTrackingRepairScheduling
    @ObservationIgnored private let eventTimeClock: EventTimeClock
    @ObservationIgnored private weak var connectedMenu: NSMenu?
    @ObservationIgnored private var beginTrackingObserver: NSObjectProtocol?
    @ObservationIgnored private var didAddItemObserver: NSObjectProtocol?
    @ObservationIgnored private var endTrackingObserver: NSObjectProtocol?
    @ObservationIgnored private var shortcutMenuItem: NSMenuItem?
    @ObservationIgnored private var shortcutActionTarget: MenuBarShortcutActionTarget?
    @ObservationIgnored private var shortcutProvider: ShortcutProvider?
    @ObservationIgnored private var openAction: PresentationAction?
    @ObservationIgnored private var closeAction: PresentationAction?
    @ObservationIgnored private var trackingBeginAction: PresentationAction?
    @ObservationIgnored private var trackingEndAction: PresentationAction?
    @ObservationIgnored private var activeTrackingStart: TimeInterval?
    @ObservationIgnored private var completedTrackingInterval: ClosedRange<TimeInterval>?
    @ObservationIgnored private var trackingGeneration: UInt64 = 0
    @ObservationIgnored private var scheduledRepairGeneration: UInt64?

    init(
        notificationCenter: NotificationCenter = .default,
        trackingRepairScheduler: any MenuTrackingRepairScheduling = MenuTrackingRunLoopRepairScheduler(),
        eventTimeClock: @escaping EventTimeClock = { GetCurrentEventTime() }
    ) {
        self.notificationCenter = notificationCenter
        self.trackingRepairScheduler = trackingRepairScheduler
        self.eventTimeClock = eventTimeClock
    }

    func connect(
        menu: NSMenu,
        open: @escaping PresentationAction,
        close: @escaping PresentationAction,
        shortcutProvider: @escaping ShortcutProvider = { nil },
        onTrackingBegin: @escaping PresentationAction = {},
        onTrackingEnd: @escaping PresentationAction = {}
    ) {
        if connectedMenu === menu {
            openAction = open
            closeAction = close
            self.shortcutProvider = shortcutProvider
            trackingBeginAction = onTrackingBegin
            trackingEndAction = onTrackingEnd
            shortcutActionTarget?.action = close
            ensureShortcutMenuItemInstalled()
            configureShortcutMenuItem()
            return
        }

        disconnect()
        connectedMenu = menu
        openAction = open
        closeAction = close
        self.shortcutProvider = shortcutProvider
        trackingBeginAction = onTrackingBegin
        trackingEndAction = onTrackingEnd
        createShortcutMenuItem(close: close)
        ensureShortcutMenuItemInstalled()
        configureShortcutMenuItem()

        beginTrackingObserver = notificationCenter.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: menu,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.beginTracking()
            }
        }

        endTrackingObserver = notificationCenter.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: menu,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.endTracking()
            }
        }

        didAddItemObserver = notificationCenter.addObserver(
            forName: NSMenu.didAddItemNotification,
            object: menu,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleTrackingRepairIfNeeded()
            }
        }
    }

    func disconnect() {
        if let beginTrackingObserver {
            notificationCenter.removeObserver(beginTrackingObserver)
        }
        if let endTrackingObserver {
            notificationCenter.removeObserver(endTrackingObserver)
        }
        if let didAddItemObserver {
            notificationCenter.removeObserver(didAddItemObserver)
        }
        endTracking()
        trackingGeneration &+= 1
        scheduledRepairGeneration = nil
        if let shortcutMenuItem {
            shortcutMenuItem.keyEquivalent = ""
            shortcutMenuItem.keyEquivalentModifierMask = []
            shortcutMenuItem.target = nil
            shortcutMenuItem.menu?.removeItem(shortcutMenuItem)
        }
        shortcutActionTarget?.action = nil

        beginTrackingObserver = nil
        didAddItemObserver = nil
        endTrackingObserver = nil
        shortcutMenuItem = nil
        shortcutActionTarget = nil
        shortcutProvider = nil
        connectedMenu = nil
        openAction = nil
        closeAction = nil
        trackingBeginAction = nil
        trackingEndAction = nil
        activeTrackingStart = nil
        completedTrackingInterval = nil
    }

    func toggle(eventTime: TimeInterval) {
        guard connectedMenu != nil, let openAction, let closeAction else {
            isPresented = true
            return
        }

        if isInActiveTrackingInterval(eventTime) {
            closeAction()
            return
        }

        if completedTrackingInterval?.contains(eventTime) == true {
            return
        }

        openAction()
    }

    private func isInActiveTrackingInterval(_ eventTime: TimeInterval) -> Bool {
        guard let activeTrackingStart else { return false }
        let currentEventTime = eventTimeClock()
        guard activeTrackingStart <= currentEventTime else { return false }
        return (activeTrackingStart ... currentEventTime).contains(eventTime)
    }

    private func beginTracking() {
        guard activeTrackingStart == nil else { return }
        ensureShortcutMenuItemInstalled()
        configureShortcutMenuItem()
        trackingGeneration &+= 1
        scheduledRepairGeneration = nil
        activeTrackingStart = eventTimeClock()
        trackingBeginAction?()
    }

    private func endTracking() {
        guard activeTrackingStart != nil else { return }
        completeTrackingInterval()
        scheduledRepairGeneration = nil
        trackingEndAction?()
    }

    private func completeTrackingInterval() {
        guard let activeTrackingStart else { return }
        let end = eventTimeClock()
        if activeTrackingStart <= end {
            completedTrackingInterval = activeTrackingStart ... end
        }
        self.activeTrackingStart = nil
    }

    private func createShortcutMenuItem(close: @escaping PresentationAction) {
        let actionTarget = MenuBarShortcutActionTarget(action: close)
        let item = NSMenuItem(
            title: "",
            action: #selector(MenuBarShortcutActionTarget.performShortcut(_:)),
            keyEquivalent: ""
        )
        item.target = actionTarget
        item.isHidden = true
        item.isEnabled = true
        item.allowsKeyEquivalentWhenHidden = true
        shortcutActionTarget = actionTarget
        shortcutMenuItem = item
    }

    private func ensureShortcutMenuItemInstalled() {
        guard let connectedMenu, let shortcutMenuItem else { return }
        let installedItems = connectedMenu.items.filter { $0 === shortcutMenuItem }
        guard shortcutMenuItem.menu !== connectedMenu || installedItems.count != 1 else { return }

        shortcutMenuItem.menu?.removeItem(shortcutMenuItem)
        let installedIndexes = connectedMenu.items.indices.filter {
            connectedMenu.items[$0] === shortcutMenuItem
        }
        for index in installedIndexes.reversed() {
            connectedMenu.removeItem(at: index)
        }
        connectedMenu.addItem(shortcutMenuItem)
    }

    private func configureShortcutMenuItem() {
        guard let shortcutMenuItem else { return }
        guard
            let shortcut = shortcutProvider?(),
            let keyEquivalent = MenuBarKeyEquivalent(shortcut: shortcut)
        else {
            shortcutMenuItem.keyEquivalent = ""
            shortcutMenuItem.keyEquivalentModifierMask = []
            return
        }

        shortcutMenuItem.keyEquivalent = keyEquivalent.key
        shortcutMenuItem.keyEquivalentModifierMask = keyEquivalent.modifiers
    }

    private func scheduleTrackingRepairIfNeeded() {
        guard
            activeTrackingStart != nil,
            let connectedMenu,
            let shortcutMenuItem,
            shortcutMenuItem.menu !== connectedMenu
            || connectedMenu.items.filter({ $0 === shortcutMenuItem }).count != 1
        else { return }

        let generation = trackingGeneration
        guard scheduledRepairGeneration != generation else { return }
        scheduledRepairGeneration = generation
        trackingRepairScheduler.schedule { [weak self, weak connectedMenu] in
            self?.repairShortcutMenuItem(
                in: connectedMenu,
                generation: generation
            )
        }
    }

    private func repairShortcutMenuItem(
        in menu: NSMenu?,
        generation: UInt64
    ) {
        guard scheduledRepairGeneration == generation else { return }
        defer { scheduledRepairGeneration = nil }
        guard
            trackingGeneration == generation,
            activeTrackingStart != nil,
            let menu,
            connectedMenu === menu,
            let shortcutMenuItem,
            shortcutMenuItem.menu !== menu
            || menu.items.filter({ $0 === shortcutMenuItem }).count != 1
        else { return }

        ensureShortcutMenuItemInstalled()
        configureShortcutMenuItem()
    }
}

@MainActor
private final class MenuBarShortcutActionTarget: NSObject {
    var action: MenuBarPresentationState.PresentationAction?

    init(action: @escaping MenuBarPresentationState.PresentationAction) {
        self.action = action
    }

    @objc
    func performShortcut(_: NSMenuItem) {
        action?()
    }
}
