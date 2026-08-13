import SwiftUI

struct BrowserPickerView: View {
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast
    @FocusState private var isFocused: Bool

    let store: BrowserPickerStore
    let onSelect: (BrowserApplication) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if store.browsers.isEmpty {
                ContentUnavailableView(
                    "No Browsers Available",
                    systemImage: "globe.badge.chevron.backward",
                    description: Text("Install or enable a browser that can open this URL.")
                )
                .frame(maxWidth: .infinity, minHeight: 120)
                .accessibilityIdentifier(
                    AccessibilityIdentifier.pickerEmptyState
                )
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(
                            Array(store.browsers.enumerated()),
                            id: \.element.id
                        ) { index, browser in
                            browserRow(
                                browser,
                                at: index
                            )
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(12)
        .frame(width: 360)
        .background {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Rectangle()
                    .fill(.regularMaterial)
            }
        }
        .clipShape(.rect(cornerRadius: 14))
        .focusable()
        .focused($isFocused)
        .defaultFocus($isFocused, true)
        .onKeyPress(.upArrow) {
            store.moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            store.moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.return) {
            activateSelection()
        }
        .onKeyPress(.space) {
            activateSelection()
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
    }

    private func activateSelection() -> KeyPress.Result {
        if let browser = store.selectedBrowser {
            onSelect(browser)
        }
        return .handled
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Open with")
                .font(.headline)

            Text(store.destination.url.host() ?? store.destination.url.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityLabel("Destination \(store.destination.url.absoluteString)")
                .accessibilityIdentifier(
                    AccessibilityIdentifier.pickerDestination
                )
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }

    @ViewBuilder
    private func browserRow(
        _ browser: BrowserApplication,
        at index: Int
    ) -> some View {
        let button = Button {
            store.select(index: index)
            onSelect(browser)
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: browser.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)

                Text(browser.browser.displayName)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if index < 9 {
                    Text("\(index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .contentShape(.rect)
            .background(
                store.selectedIndex == index
                    ? Color.accentColor.opacity(
                        colorSchemeContrast == .increased ? 0.42 : 0.18
                    )
                    : Color.clear,
                in: .rect(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open in \(browser.browser.displayName)")
        .accessibilityHint("Opens the requested URL in this browser")
        .accessibilityAddTraits(
            store.selectedIndex == index ? .isSelected : []
        )
        .accessibilityIdentifier(
            AccessibilityIdentifier.pickerBrowser(
                bundleIdentifier: browser.browser.bundleIdentifier
            )
        )
        .onHover { isHovering in
            if isHovering {
                store.select(index: index)
            }
        }

        if index < 9 {
            button.keyboardShortcut(
                KeyEquivalent(
                    Character(String(index + 1))
                ),
                modifiers: []
            )
        } else {
            button
        }
    }
}
