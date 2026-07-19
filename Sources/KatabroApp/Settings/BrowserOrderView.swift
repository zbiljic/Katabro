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

            Text("Katabro shows browsers in this order. Newly installed browsers are added at the end.")
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
            }

            HStack {
                Button("Refresh") {
                    Task {
                        await loadBrowsers()
                    }
                }

                Button("Reset Order") {
                    preferencesStore.resetBrowserOrder()
                    browsers = defaultBrowsers
                }
                .disabled(browsers.isEmpty)

                Spacer()
            }
        }
        .task {
            await loadBrowsers()
        }
    }

    private func browserRow(
        _ browser: BrowserApplication,
        at index: Int
    ) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: browser.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            Text(browser.browser.displayName)

            Spacer()

            Button {
                moveBrowser(
                    at: index,
                    by: -1
                )
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(index == browsers.startIndex)
            .accessibilityLabel("Move \(browser.browser.displayName) up")

            Button {
                moveBrowser(
                    at: index,
                    by: 1
                )
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(index == browsers.index(before: browsers.endIndex))
            .accessibilityLabel("Move \(browser.browser.displayName) down")
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
        preferencesStore.setBrowserOrder(
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
        preferencesStore.setBrowserOrder(
            browsers.map(\.browser.bundleIdentifier)
        )
    }
}
