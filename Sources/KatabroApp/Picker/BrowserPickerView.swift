import KatabroCore
import SwiftUI

struct BrowserPickerView: View {
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast
    @FocusState private var isFocused: Bool

    let store: BrowserPickerStore
    let onSelect: (BrowserLaunchTarget, Bool) -> Void
    let onCancel: () -> Void

    var body: some View {
        @Bindable var bindableStore = store

        VStack(alignment: .leading, spacing: 12) {
            header

            if store.targets.isEmpty {
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
                            Array(store.targets.enumerated()),
                            id: \.element.id
                        ) { index, target in
                            targetRow(
                                target,
                                at: index
                            )
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            Divider()

            Toggle(
                "Remember this choice for \(displayHost)",
                isOn: $bindableStore.isRememberingSelection
            )
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .accessibilityHint(
                "Future links to this exact host open with the selected option. "
                    + "You can remove the rule in Settings, Rules."
            )
            .accessibilityIdentifier(
                AccessibilityIdentifier.pickerRememberHost
            )
            .padding(.horizontal, 6)
        }
        .padding(12)
        .frame(width: BrowserPickerLayout.width)
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
        .onKeyPress(
            characters: .letters,
            phases: .down
        ) { keyPress in
            guard
                let target = store.target(
                    forPickerShortcutInput: keyPress.characters,
                    modifiers: keyPress.modifiers
                )
            else {
                return .ignored
            }

            onSelect(target, store.isRememberingSelection)
            return .handled
        }
    }

    private func activateSelection() -> KeyPress.Result {
        if let target = store.selectedTarget {
            onSelect(target, store.isRememberingSelection)
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

    // The row keeps its styling, accessibility, hover, and numeric shortcut as one unit.
    // swiftlint:disable function_body_length
    @ViewBuilder
    private func targetRow(
        _ target: BrowserLaunchTarget,
        at index: Int
    ) -> some View {
        let button = Button {
            store.select(index: index)
            onSelect(target, store.isRememberingSelection)
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: target.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(target.displayName)
                        .lineLimit(1)

                    if let detail = target.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    if let shortcut = store.pickerShortcut(for: target) {
                        Text(shortcut.displayValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                .quaternary,
                                in: .rect(cornerRadius: 4)
                            )
                            .accessibilityHidden(true)
                    }

                    if index < 9 {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
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
        .accessibilityLabel(target.accessibilityLabel)
        .accessibilityHint(
            shortcutAccessibilityHint(
                for: target,
                at: index
            )
        )
        .accessibilityAddTraits(
            store.selectedIndex == index ? .isSelected : []
        )
        .accessibilityIdentifier(
            accessibilityIdentifier(for: target)
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

    private var displayHost: String {
        ExactHostRoutingRule.normalizedHost(
            store.destination.url.host() ?? ""
        ) ?? "this host"
    }

    // swiftlint:enable function_body_length

    private func shortcutAccessibilityHint(
        for target: BrowserLaunchTarget,
        at index: Int
    ) -> String {
        let letter = store.pickerShortcut(
            for: target
        )?.displayValue
        let number = index < 9 ? String(index + 1) : nil
        let shortcuts = [letter, number].compactMap(\.self)

        guard !shortcuts.isEmpty else {
            return "Opens the requested URL in this browser."
        }

        return "Shortcuts \(shortcuts.joined(separator: " or "))."
    }

    private func accessibilityIdentifier(
        for target: BrowserLaunchTarget
    ) -> String {
        switch target.kind {
        case .standard:
            AccessibilityIdentifier.pickerBrowser(
                bundleIdentifier: target.browser.browser.bundleIdentifier
            )
        case .privateWindow, .profile:
            AccessibilityIdentifier.pickerTarget(
                identifier: target.id
            )
        }
    }
}
