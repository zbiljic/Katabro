// Deterministic fixtures and their review window intentionally live together.
// swiftlint:disable file_length
#if DEBUG
    import AppKit
    import KatabroCore
    import SwiftUI

    struct DevelopmentUIError: LocalizedError {
        let message: String

        var errorDescription: String? {
            message
        }
    }

    enum DevelopmentUISurface: String, CaseIterable {
        case menu
        case onboarding
        case picker
        case settings
    }

    enum DevelopmentUIState: String, CaseIterable {
        case normal
        case loading
        case noBrowsers = "no-browsers"
        case browserDiscoveryError = "browser-discovery-error"
        case serviceErrors = "service-errors"
        case manyBrowsers = "many-browsers"
        case browserProfiles = "browser-profiles"
        case scriptSetup = "script-setup"
        case scriptReplace = "script-replace"

        var settingsInitialPane: SettingsPane {
            switch self {
            case .normal, .serviceErrors:
                .general
            case .loading, .noBrowsers, .browserDiscoveryError, .manyBrowsers, .browserProfiles, .scriptSetup,
                 .scriptReplace:
                .browsers
            }
        }

        var launcherHelperInstallationState: LauncherHelperInstallationState {
            switch self {
            case .browserProfiles:
                .current
            case .scriptReplace:
                .custom
            default:
                .missing
            }
        }
    }

    enum DevelopmentUIAppearance: String, CaseIterable {
        case system
        case light
        case dark

        var colorScheme: ColorScheme? {
            switch self {
            case .system:
                nil
            case .light:
                .light
            case .dark:
                .dark
            }
        }
    }

    struct DevelopmentUIConfiguration: Equatable {
        static let surfaceArgument = "--ui-review"
        static let stateArgument = "--ui-state"
        static let appearanceArgument = "--ui-appearance"
        static let preferencesSuiteArgument = "--ui-preferences-suite"
        static let resetPreferencesArgument = "--ui-reset-preferences"
        let surface: DevelopmentUISurface
        let state: DevelopmentUIState
        var appearance = DevelopmentUIAppearance.system
        var preferencesSuite: String?
        var resetsPreferences = false

        var windowTitle: String {
            "Katabro UI Review — \(surface.rawValue.capitalized)"
        }

        static func current(
            arguments: [String] = ProcessInfo.processInfo.arguments
        ) -> Self? {
            guard
                let surfaceValue = value(
                    following: surfaceArgument,
                    in: arguments
                ),
                let surface = DevelopmentUISurface(
                    rawValue: surfaceValue
                )
            else {
                return nil
            }

            let state = value(
                following: stateArgument,
                in: arguments
            ).flatMap(DevelopmentUIState.init(rawValue:)) ?? .normal
            let appearance = value(
                following: appearanceArgument,
                in: arguments
            ).flatMap(DevelopmentUIAppearance.init(rawValue:)) ?? .system
            let preferencesSuite = value(
                following: preferencesSuiteArgument,
                in: arguments
            )

            return Self(
                surface: surface,
                state: state,
                appearance: appearance,
                preferencesSuite: preferencesSuite,
                resetsPreferences: arguments.contains(
                    resetPreferencesArgument
                )
            )
        }

        private static func value(
            following argument: String,
            in arguments: [String]
        ) -> String? {
            guard
                let index = arguments.firstIndex(of: argument),
                arguments.indices.contains(index + 1)
            else {
                return nil
            }

            return arguments[index + 1]
        }
    }

    @MainActor
    private final class DevelopmentFolderReadState {
        var available = true
    }

    @MainActor
    enum DevelopmentUIFixtures { // swiftlint:disable:this type_body_length
        // swiftlint:disable:next function_body_length
        static func dependencies(
            for state: DevelopmentUIState,
            preferencesSuite: String? = nil,
            resetsPreferences: Bool = false
        ) -> AppDependencies {
            let serviceError = state == .serviceErrors
                ? "The development fixture could not update this system setting."
                : nil
            let discoveredBrowsers: [BrowserApplication]
            let discoveryBehavior: DevelopmentBrowserDiscovery.Behavior

            switch state {
            case .loading:
                discoveredBrowsers = []
                discoveryBehavior = .loading
            case .noBrowsers:
                discoveredBrowsers = []
                discoveryBehavior = .browsers([])
            case .browserDiscoveryError:
                discoveredBrowsers = []
                discoveryBehavior = .error(
                    DevelopmentUIError(
                        message: "The development fixture could not query Launch Services."
                    )
                )
            case .manyBrowsers:
                discoveredBrowsers = browsers(
                    count: 12
                )
                discoveryBehavior = .browsers(
                    discoveredBrowsers
                )
            case .normal, .serviceErrors, .browserProfiles, .scriptSetup, .scriptReplace:
                discoveredBrowsers = browsers(
                    count: 4
                )
                discoveryBehavior = .browsers(
                    discoveredBrowsers
                )
            }

            let initialPreferences = AppPreferences(
                browserOrder: discoveredBrowsers.map(
                    \.browser.bundleIdentifier
                ),
                pickerShortcuts: pickerShortcuts(
                    for: state
                ),
                hasCompletedOnboarding: true,
                exactHostRoutingRules: state == .normal
                    ? [
                        ExactHostRoutingRule(
                            host: "example.com",
                            targetIdentifier: "com.example.browser"
                        ),
                        ExactHostRoutingRule(
                            host: "developer.apple.com",
                            targetIdentifier: "com.example.research"
                        ),
                    ].compactMap(\.self)
                    : []
            )
            let preferencesStore: PreferencesStore
            let configurationFolderClient: ConfigurationFolderClient
            let profileStore = BrowserProfileStore(
                profilesByBrowserIdentifier: state == .browserProfiles
                    ? developmentProfiles
                    : [:],
                preservesUnbookmarkedProfiles: true
            )
            let userScriptBridge = UserScriptBridge(
                initialInstallationState: state.launcherHelperInstallationState
            ) { true }

            if let preferencesSuite {
                let suiteName = "com.zbiljic.katabro.ui-review.\(preferencesSuite)"

                if let userDefaults = UserDefaults(suiteName: suiteName) {
                    if resetsPreferences {
                        userDefaults.removePersistentDomain(
                            forName: suiteName
                        )
                    }
                    preferencesStore = PreferencesStore.live(
                        userDefaults: userDefaults,
                        iCloudClient: nil,
                        defaultPreferences: initialPreferences
                    )
                } else {
                    preferencesStore = PreferencesStore(
                        initialPreferences: initialPreferences,
                        syncMethod: .thisMac
                    )
                }
            } else {
                preferencesStore = PreferencesStore(
                    initialPreferences: initialPreferences,
                    initialSyncStatus: state == .serviceErrors
                        ? .localOnly
                        : .available,
                    syncMethod: state == .serviceErrors ? .iCloud : .thisMac
                )
            }

            if preferencesSuite == nil, state == .normal || state == .serviceErrors {
                let snapshot = preferencesStore.browserSettingsSnapshot()
                let fixtureReadState = DevelopmentFolderReadState()
                let fakeClient = FilePreferencesClient(
                    injectedRead: {
                        !fixtureReadState.available
                            ? .unavailable
                            : .snapshot(snapshot, bytes: (try? snapshot.encodedData()) ?? Data())
                    },
                    injectedWrite: { _ in state != .serviceErrors },
                    displayName: "Shared Katabro",
                    displayLocation: "~/Documents/Shared Katabro"
                )
                _ = preferencesStore.configureFolderSync(
                    client: fakeClient,
                    displayName: "Shared Katabro"
                )
                fixtureReadState.available = state != .serviceErrors
                if state == .serviceErrors {
                    preferencesStore.refreshActiveSync()
                }
                let chooserSnapshot = BrowserSettingsSnapshot(
                    browserOrder: ["com.example.remote"],
                    pickerShortcuts: [:],
                    exactHostRoutingRules: []
                )
                let chooserURL = URL(fileURLWithPath: "/fixture/Shared Katabro", isDirectory: true)
                configurationFolderClient = ConfigurationFolderClient(
                    chooseDirectory: { chooserURL },
                    makeClient: { _ in
                        FilePreferencesClient(
                            injectedRead: {
                                state == .serviceErrors
                                    ? .unavailable
                                    : .snapshot(
                                        chooserSnapshot,
                                        bytes: (try? chooserSnapshot.encodedData()) ?? Data()
                                    )
                            },
                            injectedWrite: { _ in state != .serviceErrors },
                            displayName: "Shared Katabro",
                            displayLocation: "~/Documents/Shared Katabro"
                        )
                    }
                )
            } else {
                configurationFolderClient = ConfigurationFolderClient { nil }
            }

            return AppDependencies(
                browserDiscovery: DevelopmentBrowserDiscovery(
                    behavior: discoveryBehavior
                ),
                browserLauncher: DevelopmentBrowserLauncher(),
                defaultBrowserClient: .development(
                    status: state == .serviceErrors ? .notCurrent : .current,
                    lastError: serviceError
                ),
                errorPresenter: DevelopmentRoutingErrorPresenter(),
                loginItemClient: .development(
                    status: state == .serviceErrors ? .disabled : .enabled,
                    lastError: serviceError
                ),
                routingDecisionClient: .exactHostRules,
                browserProfileStore: profileStore,
                preferencesStore: preferencesStore,
                configurationFolderClient: configurationFolderClient,
                userScriptBridge: userScriptBridge,
                allowsSystemProfileConfiguration: state == .scriptSetup || state == .scriptReplace
            )
        }

        static func browsers(
            for state: DevelopmentUIState
        ) -> [BrowserApplication] {
            switch state {
            case .loading, .noBrowsers, .browserDiscoveryError:
                []
            case .manyBrowsers:
                browsers(
                    count: 12
                )
            case .normal, .serviceErrors, .browserProfiles, .scriptSetup, .scriptReplace:
                browsers(
                    count: 4
                )
            }
        }

        static func pickerStore(
            for state: DevelopmentUIState,
            pickerShortcuts: [String: PickerShortcut]? = nil
        ) -> BrowserPickerStore {
            let destination = try? IncomingURL(
                "https://developer.apple.com/documentation/swiftui"
            )

            return BrowserPickerStore(
                destination: destination ?? fallbackDestination(),
                targets: pickerTargets(for: state),
                pickerShortcuts: pickerShortcuts ?? self.pickerShortcuts(for: state)
            )
        }

        static func pickerHeight(
            for state: DevelopmentUIState
        ) -> CGFloat {
            BrowserPickerLayout.height(
                browserCount: pickerTargets(for: state).count
            )
        }

        private static func fallbackDestination() -> IncomingURL {
            do {
                return try IncomingURL(
                    "https://example.com"
                )
            } catch {
                preconditionFailure(
                    "The static development URL must be valid: \(error)"
                )
            }
        }

        private static func browsers(
            count: Int
        ) -> [BrowserApplication] {
            let definitions = [
                ("com.apple.Safari", "Safari", "safari"),
                ("com.google.Chrome", "Google Chrome", "globe"),
                ("org.mozilla.firefox", "Firefox", "flame"),
                ("company.thebrowser.Browser", "Arc", "circle.grid.2x2"),
                ("com.microsoft.edgemac", "Microsoft Edge", "square.stack.3d.up"),
                ("com.brave.Browser", "Brave Browser", "shield"),
                ("com.operasoftware.Opera", "Opera", "circle"),
                ("com.vivaldi.Vivaldi", "Vivaldi", "v.square"),
                ("org.chromium.Chromium", "Chromium", "gearshape.2"),
                ("com.kagi.kagimacOS", "Orion", "sparkles"),
                (
                    "com.duckduckgo.macos.browser",
                    "DuckDuckGo Privacy Browser — Long Name Fixture",
                    "hand.raised"
                ),
                (
                    "com.apple.SafariTechnologyPreview",
                    "Safari Technology Preview — Long Name Fixture",
                    "hammer"
                ),
            ]

            return definitions.prefix(count).map { identifier, name, symbol in
                BrowserApplication(
                    browser: Browser(
                        bundleIdentifier: identifier,
                        displayName: name
                    ),
                    applicationURL: URL(
                        fileURLWithPath: "/Applications/\(name).app"
                    ),
                    icon: NSImage(
                        systemSymbolName: symbol,
                        accessibilityDescription: name
                    ) ?? NSImage(
                        size: NSSize(
                            width: 32,
                            height: 32
                        )
                    )
                )
            }
        }

        private static func pickerShortcuts(
            for state: DevelopmentUIState
        ) -> [String: PickerShortcut] {
            guard
                state != .loading,
                state != .noBrowsers,
                state != .browserDiscoveryError
            else {
                return [:]
            }

            let definitions = [
                ("com.apple.Safari", "s"),
                ("com.google.Chrome", "c"),
                ("org.mozilla.firefox", "f"),
                ("company.thebrowser.Browser", "a"),
                ("com.microsoft.edgemac", "e"),
                ("com.brave.Browser", "b"),
            ]
            let assignmentCount = state == .manyBrowsers ? definitions.count : 2

            return Dictionary(
                uniqueKeysWithValues: definitions.prefix(assignmentCount).compactMap { identifier, value in
                    PickerShortcut(value).map {
                        (identifier, $0)
                    }
                }
            )
        }

        private static let developmentProfiles: [String: [BrowserProfile]] = [
            "com.google.chrome": [
                BrowserProfile(
                    identifier: "Default",
                    displayName: "Personal",
                    launchValue: "Default",
                    family: .chromium
                ),
                BrowserProfile(
                    identifier: "Profile 2",
                    displayName: "Work",
                    launchValue: "Profile 2",
                    family: .chromium
                ),
            ],
            "org.mozilla.firefox": [
                BrowserProfile(
                    identifier: "Profiles/dev-edition-default",
                    displayName: "Developer",
                    launchValue: "/Users/reviewer/Library/Application Support/Firefox/Profiles/dev-edition-default",
                    family: .firefox
                ),
            ],
        ]

        private static func pickerTargets(
            for state: DevelopmentUIState
        ) -> [BrowserLaunchTarget] {
            let browsers = browsers(for: state)
            let store = BrowserProfileStore(
                profilesByBrowserIdentifier: state == .browserProfiles
                    ? developmentProfiles
                    : [:],
                preservesUnbookmarkedProfiles: true
            )
            return store.targets(
                for: browsers,
                includesArgumentTargets: state == .browserProfiles
            )
        }
    }

    @MainActor
    private struct DevelopmentBrowserDiscovery: BrowserDiscovering {
        enum Behavior {
            case browsers([BrowserApplication])
            case error(any Error)
            case loading
        }

        let behavior: Behavior

        func browsers(
            for _: IncomingURL
        ) async throws -> [BrowserApplication] {
            switch behavior {
            case let .browsers(browsers):
                return browsers
            case let .error(error):
                throw error
            case .loading:
                try await Task.sleep(
                    for: .seconds(3600)
                )
                return []
            }
        }
    }

    @MainActor
    private struct DevelopmentBrowserLauncher: BrowserLaunching {
        func open(
            _: IncomingURL,
            with _: BrowserLaunchTarget
        ) async throws {}
    }

    @MainActor
    private struct DevelopmentRoutingErrorPresenter: RoutingErrorPresenting {
        func present(
            _: any Error
        ) {}
    }

    struct DevelopmentUIReviewView: View {
        let configuration: DevelopmentUIConfiguration
        let dependencies: AppDependencies
        let onboardingCoordinator: OnboardingWindowCoordinator
        let pickerCoordinator: BrowserPickerCoordinator

        var body: some View {
            Group {
                switch configuration.surface {
                case .settings:
                    SettingsView(
                        browserDiscovery: dependencies.browserDiscovery,
                        browserProfileStore: dependencies.browserProfileStore,
                        defaultBrowserClient: dependencies.defaultBrowserClient,
                        loginItemClient: dependencies.loginItemClient,
                        preferencesStore: dependencies.preferencesStore,
                        configurationFolderClient: dependencies.configurationFolderClient,
                        userScriptBridge: dependencies.userScriptBridge,
                        allowsSystemProfileConfiguration: dependencies.allowsSystemProfileConfiguration,
                        initialPane: configuration.state.settingsInitialPane
                    )
                case .onboarding:
                    OnboardingView(
                        defaultBrowserClient: dependencies.defaultBrowserClient,
                        preferencesStore: dependencies.preferencesStore
                    ) {}
                case .picker:
                    DevelopmentPickerReviewView(
                        state: configuration.state,
                        preferencesStore: dependencies.preferencesStore
                    )
                case .menu:
                    MenuBarView(
                        defaultBrowserClient: dependencies.defaultBrowserClient,
                        onboardingCoordinator: onboardingCoordinator,
                        pickerCoordinator: pickerCoordinator,
                        preferencesStore: dependencies.preferencesStore
                    )
                    .padding(12)
                    .frame(width: 280)
                }
            }
            .preferredColorScheme(
                configuration.appearance.colorScheme
            )
        }
    }

    private struct DevelopmentPickerReviewView: View {
        @State private var selectedBrowserName: String?
        @State private var selectionCount = 0
        @State private var cancellationCount = 0
        let state: DevelopmentUIState
        let preferencesStore: PreferencesStore
        var body: some View {
            VStack(spacing: 4) {
                BrowserPickerView(
                    store: DevelopmentUIFixtures.pickerStore(
                        for: state,
                        pickerShortcuts: preferencesStore.pickerShortcuts
                    ),
                    onSelect: recordSelection
                ) {
                    cancellationCount += 1
                }

                Text(selectionReceipt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Picker selection receipt")
                    .accessibilityValue(selectionReceipt)
                    .accessibilityIdentifier(AccessibilityIdentifier.pickerSelectionReceipt)

                Text(cancellationReceipt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Picker cancellation receipt")
                    .accessibilityValue(cancellationReceipt)
                    .accessibilityIdentifier(AccessibilityIdentifier.pickerCancellationReceipt)
            }
            .frame(minHeight: DevelopmentUIFixtures.pickerHeight(for: state), alignment: .top)
        }

        private var selectionReceipt: String {
            selectedBrowserName.map {
                "\($0) selected \(selectionCount) time\(selectionCount == 1 ? "" : "s")"
            } ?? "No browser selected"
        }

        private var cancellationReceipt: String {
            cancellationCount == 0
                ? "Picker not cancelled"
                : "Picker cancelled \(cancellationCount) time\(cancellationCount == 1 ? "" : "s")"
        }

        private func recordSelection(
            _ target: BrowserLaunchTarget,
            remembersSelection _: Bool
        ) {
            selectedBrowserName = target.displayName
            selectionCount += 1
        }
    }

    @MainActor
    final class DevelopmentUIWindowCoordinator: NSObject, NSWindowDelegate {
        private let configuration: DevelopmentUIConfiguration
        private let dependencies: AppDependencies
        private let onboardingCoordinator: OnboardingWindowCoordinator
        private let pickerCoordinator: BrowserPickerCoordinator
        private var window: NSWindow?

        init(
            configuration: DevelopmentUIConfiguration,
            dependencies: AppDependencies,
            onboardingCoordinator: OnboardingWindowCoordinator,
            pickerCoordinator: BrowserPickerCoordinator
        ) {
            self.configuration = configuration
            self.dependencies = dependencies
            self.onboardingCoordinator = onboardingCoordinator
            self.pickerCoordinator = pickerCoordinator
        }

        func present() {
            if let window {
                NSApplication.shared.activate()
                window.makeKeyAndOrderFront(nil)
                return
            }

            let window = NSWindow(
                contentRect: NSRect(
                    origin: .zero,
                    size: contentSize
                ),
                styleMask: [
                    .titled,
                    .closable,
                    .miniaturizable,
                    .resizable,
                ],
                backing: .buffered,
                defer: false
            )
            let hostingController = NSHostingController(
                rootView: DevelopmentUIReviewView(
                    configuration: configuration,
                    dependencies: dependencies,
                    onboardingCoordinator: onboardingCoordinator,
                    pickerCoordinator: pickerCoordinator
                )
            )
            hostingController.sizingOptions = []
            window.contentViewController = hostingController
            window.setContentSize(
                contentSize
            )
            window.delegate = self
            window.isReleasedWhenClosed = false
            window.minSize = contentSize
            window.title = configuration.windowTitle
            window.center()

            self.window = window
            NSApplication.shared.activate()
            window.makeKeyAndOrderFront(nil)
        }

        func windowWillClose(
            _: Notification
        ) {
            window = nil
        }

        private var contentSize: NSSize {
            switch configuration.surface {
            case .settings:
                NSSize(
                    width: 620,
                    height: 640
                )
            case .onboarding:
                NSSize(
                    width: 520,
                    height: 440
                )
            case .picker:
                NSSize(
                    width: 360,
                    height: DevelopmentUIFixtures.pickerHeight(
                        for: configuration.state
                    )
                )
            case .menu:
                NSSize(
                    width: 300,
                    height: 320
                )
            }
        }
    }
#endif
