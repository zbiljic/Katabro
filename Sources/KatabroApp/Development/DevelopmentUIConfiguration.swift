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

        let surface: DevelopmentUISurface
        let state: DevelopmentUIState
        var appearance = DevelopmentUIAppearance.system

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

            return Self(
                surface: surface,
                state: state,
                appearance: appearance
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
    enum DevelopmentUIFixtures {
        static func dependencies(
            for state: DevelopmentUIState
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
            case .normal, .serviceErrors:
                discoveredBrowsers = browsers(
                    count: 4
                )
                discoveryBehavior = .browsers(
                    discoveredBrowsers
                )
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
                preferencesStore: PreferencesStore(
                    initialPreferences: AppPreferences(
                        browserOrder: discoveredBrowsers.map(
                            \.browser.bundleIdentifier
                        ),
                        hasCompletedOnboarding: true
                    )
                )
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
            case .normal, .serviceErrors:
                browsers(
                    count: 4
                )
            }
        }

        static func pickerStore(
            for state: DevelopmentUIState
        ) -> BrowserPickerStore {
            let destination = try? IncomingURL(
                "https://developer.apple.com/documentation/swiftui"
            )

            return BrowserPickerStore(
                destination: destination ?? fallbackDestination(),
                browsers: browsers(
                    for: state
                )
            )
        }

        static func pickerHeight(
            for state: DevelopmentUIState
        ) -> CGFloat {
            CGFloat(
                min(
                    560,
                    max(
                        180,
                        92 + browsers(
                            for: state
                        ).count * 52
                    )
                )
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
                ("com.duckduckgo.macos.browser", "DuckDuckGo", "hand.raised"),
                ("com.apple.SafariTechnologyPreview", "Safari Technology Preview", "hammer"),
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
            with _: BrowserApplication
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
                        defaultBrowserClient: dependencies.defaultBrowserClient,
                        loginItemClient: dependencies.loginItemClient,
                        preferencesStore: dependencies.preferencesStore
                    )
                case .onboarding:
                    OnboardingView(
                        defaultBrowserClient: dependencies.defaultBrowserClient,
                        preferencesStore: dependencies.preferencesStore
                    ) {}
                case .picker:
                    BrowserPickerView(
                        store: DevelopmentUIFixtures.pickerStore(
                            for: configuration.state
                        ),
                        onSelect: { _ in },
                        onCancel: {}
                    )
                    .frame(
                        minHeight: DevelopmentUIFixtures.pickerHeight(
                            for: configuration.state
                        ),
                        alignment: .top
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
            window.contentViewController = NSHostingController(
                rootView: DevelopmentUIReviewView(
                    configuration: configuration,
                    dependencies: dependencies,
                    onboardingCoordinator: onboardingCoordinator,
                    pickerCoordinator: pickerCoordinator
                )
            )
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
