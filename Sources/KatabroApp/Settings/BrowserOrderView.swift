import KatabroCore
import SwiftUI

struct BrowserOrderView: View {
    let browserDiscovery: any BrowserDiscovering
    let preferencesStore: PreferencesStore

    @State private var browsers: [BrowserApplication] = []
    @State private var defaultBrowsers: [BrowserApplication] = []
    @State private var discoveryError: String?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Browser Order")
                .font(.headline)

            Text(
                "Checked browsers appear in the picker. "
                    + "Their list order controls the picker order, "
                    + "and newly installed browsers are shown by default."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            if isLoading {
                ProgressView("Finding browsers…")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if let discoveryError {
                ContentUnavailableView(
                    "Browsers Couldn’t Be Loaded",
                    systemImage: "exclamationmark.triangle",
                    description: Text(discoveryError)
                )
                .frame(maxWidth: .infinity, minHeight: 120)
            } else if browsers.isEmpty {
                ContentUnavailableView(
                    "No Browsers Available",
                    systemImage: "globe.badge.chevron.backward",
                    description: Text("Install or enable a browser that can open HTTPS links.")
                )
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                List {
                    ForEach(
                        Array(browsers.enumerated()),
                        id: \.element.id
                    ) { index, browser in
                        browserRow(
                            browser,
                            at: index
                        )
                    }
                    .onMove(
                        perform: moveBrowsers
                    )
                }
                .frame(minHeight: 180)
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsBrowserList
                )
            }

            HStack {
                Button("Refresh") {
                    Task {
                        await loadBrowsers()
                    }
                }
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsBrowserRefresh
                )

                Button("Reset Order") {
                    preferencesStore.resetBrowserOrder()
                    browsers = defaultBrowsers
                }
                .disabled(browsers.isEmpty)
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsBrowserReset
                )

                Button("Show All") {
                    preferencesStore.showAllBrowsers()
                }
                .disabled(preferencesStore.hiddenBrowserIdentifiers.isEmpty)
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsBrowserShowAll
                )

                Spacer()
            }
        }
        .task {
            await loadBrowsers()
        }
    }

    // The row keeps visibility and both existing move affordances in one AX element.
    // swiftlint:disable:next function_body_length
    private func browserRow(
        _ browser: BrowserApplication,
        at index: Int
    ) -> some View {
        HStack(spacing: 10) {
            Toggle(
                isOn: visibilityBinding(for: browser)
            ) {
                HStack(spacing: 10) {
                    Image(nsImage: browser.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)

                    Text(browser.browser.displayName)
                }
            }
            .toggleStyle(.checkbox)
            .disabled(
                isLastShownBrowser(browser)
            )
            .help(
                isLastShownBrowser(browser)
                    ? "At least one browser must remain shown."
                    : "Show \(browser.browser.displayName) in the picker."
            )
            .accessibilityIdentifier(
                AccessibilityIdentifier.browserVisibility(
                    bundleIdentifier: browser.browser.bundleIdentifier
                )
            )

            Spacer()

            moveButton(
                browser: browser,
                at: index,
                offset: -1,
                directionDescription: "up"
            )

            moveButton(
                browser: browser,
                at: index,
                offset: 1,
                directionDescription: "down"
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                moveBrowser(
                    at: index,
                    by: 1
                )
            case .decrement:
                moveBrowser(
                    at: index,
                    by: -1
                )
            @unknown default:
                break
            }
        }
        .accessibilityIdentifier(
            AccessibilityIdentifier.browserOrderRow(
                bundleIdentifier: browser.browser.bundleIdentifier
            )
        )
    }

    private func visibilityBinding(
        for browser: BrowserApplication
    ) -> Binding<Bool> {
        Binding(
            get: {
                preferencesStore.isBrowserShown(
                    browser.browser.bundleIdentifier,
                    among: discoveredBrowserIdentifiers
                )
            },
            set: { shown in
                preferencesStore.setBrowserShown(
                    browser.browser.bundleIdentifier,
                    shown: shown,
                    among: discoveredBrowserIdentifiers
                )
            }
        )
    }

    private func isLastShownBrowser(
        _ browser: BrowserApplication
    ) -> Bool {
        preferencesStore.isBrowserShown(
            browser.browser.bundleIdentifier,
            among: discoveredBrowserIdentifiers
        ) && !preferencesStore.canHideBrowser(
            browser.browser.bundleIdentifier,
            among: discoveredBrowserIdentifiers
        )
    }

    private var discoveredBrowserIdentifiers: [String] {
        browsers.map(\.browser.bundleIdentifier)
    }

    private func moveButton(
        browser: BrowserApplication,
        at index: Int,
        offset: Int,
        directionDescription: String
    ) -> some View {
        let isMovingUp = offset < 0

        return Button {
            moveBrowser(
                at: index,
                by: offset
            )
        } label: {
            Image(
                systemName: isMovingUp ? "chevron.up" : "chevron.down"
            )
        }
        .buttonStyle(.borderless)
        .disabled(
            isMovingUp
                ? index == browsers.startIndex
                : index == browsers.index(before: browsers.endIndex)
        )
        .accessibilityLabel(
            "Move \(browser.browser.displayName) \(directionDescription)"
        )
        .accessibilityIdentifier(
            isMovingUp
                ? AccessibilityIdentifier.browserOrderMoveUp(
                    bundleIdentifier: browser.browser.bundleIdentifier
                )
                : AccessibilityIdentifier.browserOrderMoveDown(
                    bundleIdentifier: browser.browser.bundleIdentifier
                )
        )
    }

    private func loadBrowsers() async {
        isLoading = true
        discoveryError = nil

        defer {
            isLoading = false
        }

        do {
            let destination = try IncomingURL("https://example.com")
            let discoveredBrowsers = try await browserDiscovery.browsers(
                for: destination
            )
            defaultBrowsers = discoveredBrowsers
            browsers = preferencesStore.orderedBrowsers(
                discoveredBrowsers
            )
        } catch {
            discoveryError = error.localizedDescription
        }
    }

    private func moveBrowser(
        at index: Int,
        by offset: Int
    ) {
        let destination = index + offset

        guard browsers.indices.contains(destination) else {
            return
        }

        browsers.swapAt(
            index,
            destination
        )
        preferencesStore.setVisibleBrowserOrder(
            browsers.map(\.browser.bundleIdentifier)
        )
    }

    private func moveBrowsers(
        from source: IndexSet,
        to destination: Int
    ) {
        browsers.move(
            fromOffsets: source,
            toOffset: destination
        )
        preferencesStore.setVisibleBrowserOrder(
            browsers.map(\.browser.bundleIdentifier)
        )
    }
}
