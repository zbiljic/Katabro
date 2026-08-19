import AppKit
import KatabroCore
import SwiftUI

// Compact orientation-specific controls intentionally share picker semantics.
// swiftlint:disable file_length

struct BrowserPickerHoverSelectionArbitrator: Equatable {
    private(set) var keyboardPointerPosition: CGPoint?

    mutating func keyboardNavigationOccurred(at pointerPosition: CGPoint) {
        keyboardPointerPosition = pointerPosition
    }

    mutating func shouldSelectForHover(at pointerPosition: CGPoint) -> Bool {
        guard let keyboardPointerPosition else { return true }
        guard pointerPosition != keyboardPointerPosition else { return false }
        self.keyboardPointerPosition = nil
        return true
    }
}

struct BrowserPickerSelectionScrollPolicy: Equatable {
    private(set) var hasPendingKeyboardScroll = false

    mutating func keyboardNavigationOccurred() {
        hasPendingKeyboardScroll = true
    }

    mutating func hoverSelectionOccurred() {
        hasPendingKeyboardScroll = false
    }

    mutating func consumePendingKeyboardScroll() -> Bool {
        defer { hasPendingKeyboardScroll = false }
        return hasPendingKeyboardScroll
    }
}

struct BrowserPickerView: View {
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast

    @FocusState private var isFocused: Bool
    @State private var hoverSelectionArbitrator = BrowserPickerHoverSelectionArbitrator()
    @State private var selectionScrollPolicy = BrowserPickerSelectionScrollPolicy()

    let store: BrowserPickerStore
    let onSelect: (BrowserLaunchTarget, Bool) -> Void
    let onCopyLink: () -> Void
    let onCancel: () -> Void

    private var layout: BrowserPickerLayout {
        BrowserPickerLayout(
            preferences: store.pickerPreferences,
            targetCount: store.targets.count,
            includesRememberFooter: store.canRememberSelection
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrowserPickerLayout.sectionSpacing) {
            destination

            if store.targets.isEmpty {
                emptyState
            } else {
                choices

                if store.canRememberSelection {
                    rememberChoice
                }
            }
        }
        .padding(BrowserPickerLayout.outerPadding)
        .frame(width: layout.width, height: layout.height, alignment: .topLeading)
        .background {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 14))
        .background {
            Button(
                action: {},
                label: {
                    Color.clear
                        .frame(width: layout.width, height: layout.height)
                }
            )
            .buttonStyle(.plain)
            .frame(width: layout.width, height: layout.height)
            .accessibilityLabel("Browser picker")
            .accessibilityValue(
                "\(store.pickerPreferences.orientation.displayName), "
                    + "\(store.pickerPreferences.visibleChoiceCount) visible choices"
            )
            .accessibilityIdentifier(AccessibilityIdentifier.pickerContent)
            .allowsHitTesting(false)
        }
        .focusable()
        .focused($isFocused)
        .defaultFocus($isFocused, true)
        .onKeyPress(.upArrow) {
            moveSelectionFromKeyboard(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelectionFromKeyboard(by: 1)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            guard store.pickerPreferences.orientation == .horizontal else { return .ignored }
            moveSelectionFromKeyboard(by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard store.pickerPreferences.orientation == .horizontal else { return .ignored }
            moveSelectionFromKeyboard(by: 1)
            return .handled
        }
        .onKeyPress(.return) { activateSelection() }
        .onKeyPress(.space) { activateSelection() }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
        .onKeyPress(
            characters: CharacterSet(charactersIn: "rR"),
            phases: .down
        ) { keyPress in
            guard keyPress.modifiers == [.command, .shift], store.canRememberSelection else {
                return .ignored
            }
            store.toggleRememberingSelection()
            return .handled
        }
        .onKeyPress(
            characters: CharacterSet(charactersIn: "cC"),
            phases: .down
        ) { keyPress in
            guard keyPress.modifiers == [.command] else {
                return .ignored
            }
            copyLink()
            return .handled
        }
        .onKeyPress(characters: .letters, phases: .down) { keyPress in
            guard
                let target = store.target(
                    forPickerShortcutInput: keyPress.characters,
                    modifiers: keyPress.modifiers
                )
            else {
                return .ignored
            }
            onSelect(target, store.effectiveRememberingSelection)
            return .handled
        }
    }

    @ViewBuilder private var destination: some View {
        if let destinationText {
            Text(verbatim: destinationText)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityLabel("Destination \(destinationText)")
                .accessibilityValue(store.destination.url.absoluteString)
                .help(store.destination.url.absoluteString)
                .accessibilityIdentifier(AccessibilityIdentifier.pickerDestination)
                .frame(height: BrowserPickerLayout.destinationHeight)
                .contextMenu {
                    Button(action: copyLink) {
                        Label("Copy Link", systemImage: "doc.on.doc")
                    }
                    .accessibilityIdentifier(AccessibilityIdentifier.pickerCopyLink)
                }
        }
    }

    private var destinationText: String? {
        switch store.pickerPreferences.destinationDisplay {
        case .domain:
            // swiftlint:disable opening_brace
            if
                let host = store.destination.url.host(),
                let normalizedHost = ExactHostRoutingRule.normalizedHost(host)
            {
                return normalizedHost
            }
            // swiftlint:enable opening_brace
            return store.destination.url.isFileURL
                ? store.destination.url.path(percentEncoded: false)
                : store.destination.url.absoluteString
        case .fullURL:
            return store.destination.url.absoluteString
        case .hidden:
            return nil
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Browsers Available",
            systemImage: "globe.badge.chevron.backward",
            description: Text("Install or enable a browser that can open this URL.")
        )
        .frame(maxWidth: .infinity, minHeight: BrowserPickerLayout.emptyContentHeight)
        .accessibilityIdentifier(AccessibilityIdentifier.pickerEmptyState)
    }

    private var choices: some View {
        ScrollViewReader { proxy in
            Group {
                switch store.pickerPreferences.orientation {
                case .vertical:
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: BrowserPickerLayout.rowSpacing) {
                            ForEach(Array(store.targets.enumerated()), id: \.element.id) { index, target in
                                VerticalPickerTargetButton(
                                    target: target,
                                    index: index,
                                    shortcut: store.pickerShortcut(for: target),
                                    hintMode: store.pickerPreferences.shortcutHintMode,
                                    isSelected: store.selectedIndex == index,
                                    increasedContrast: colorSchemeContrast == .increased,
                                    action: { activate(target, at: index) },
                                    hover: { pointerPosition in
                                        selectFromHover(index: index, pointerPosition: pointerPosition)
                                    }
                                )
                                .id(target.id)
                                .applyNumericShortcut(index: index)
                            }
                        }
                    }
                    .frame(height: layout.collectionViewportHeight)
                    .scrollBounceBehavior(.basedOnSize)
                    .accessibilityIdentifier(AccessibilityIdentifier.pickerScrollArea)
                case .horizontal:
                    VStack(spacing: BrowserPickerLayout.rowSpacing) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: BrowserPickerLayout.horizontalCellSpacing) {
                                ForEach(Array(store.targets.enumerated()), id: \.element.id) { index, target in
                                    HorizontalPickerTargetButton(
                                        target: target,
                                        index: index,
                                        shortcut: store.pickerShortcut(for: target),
                                        hintMode: store.pickerPreferences.shortcutHintMode,
                                        labelMode: store.pickerPreferences.horizontalLabelMode,
                                        isSelected: store.selectedIndex == index,
                                        increasedContrast: colorSchemeContrast == .increased,
                                        action: { activate(target, at: index) },
                                        hover: { pointerPosition in
                                            selectFromHover(index: index, pointerPosition: pointerPosition)
                                        }
                                    )
                                    .id(target.id)
                                    .applyNumericShortcut(index: index)
                                }
                            }
                        }
                        .frame(width: layout.collectionViewportWidth, height: layout.collectionViewportHeight)
                        .scrollBounceBehavior(.basedOnSize)
                        .accessibilityIdentifier(AccessibilityIdentifier.pickerScrollArea)

                        if let target = store.selectedTarget {
                            targetLabel(target, font: .caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(
                                    maxWidth: .infinity,
                                    minHeight: BrowserPickerLayout.horizontalSelectedLabelHeight
                                )
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
            .onChange(of: store.selectedTarget?.id) { _, selectedID in
                guard
                    let selectedID,
                    selectionScrollPolicy.consumePendingKeyboardScroll()
                else { return }
                scrollSelectionToVisibleTarget(
                    selectedID,
                    orientation: store.pickerPreferences.orientation,
                    proxy: proxy
                )
            }
        }
    }

    private var rememberChoice: some View {
        VStack(alignment: .leading, spacing: BrowserPickerLayout.sectionSpacing) {
            Divider()
            Toggle(
                isOn: Binding(
                    get: { store.isRememberingSelection },
                    set: { store.setRememberingSelection($0) }
                )
            ) {
                Text("Remember for \(Text(verbatim: displayHost).monospaced().fontWeight(.medium))")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .accessibilityLabel("Remember for \(displayHost)")
            .accessibilityHint(
                "Future links to this exact host open with the selected option. "
                    + "Press Shift-Command-R to toggle. "
                    + "You can remove the rule in Settings, Rules."
            )
            .help("Remember for \(displayHost)")
            .accessibilityIdentifier(AccessibilityIdentifier.pickerRememberHost)
        }
    }

    private var displayHost: String {
        ExactHostRoutingRule.normalizedHost(store.destination.url.host() ?? "") ?? "this host"
    }

    private func activateSelection() -> KeyPress.Result {
        if let target = store.selectedTarget {
            onSelect(target, store.effectiveRememberingSelection)
        }
        return .handled
    }

    private func copyLink() {
        onCopyLink()
    }

    private func moveSelectionFromKeyboard(by offset: Int) {
        hoverSelectionArbitrator.keyboardNavigationOccurred(at: NSEvent.mouseLocation)
        selectionScrollPolicy.keyboardNavigationOccurred()
        store.moveSelection(by: offset)
    }

    private func selectFromHover(index: Int, pointerPosition: CGPoint) {
        guard hoverSelectionArbitrator.shouldSelectForHover(at: pointerPosition) else { return }
        selectionScrollPolicy.hoverSelectionOccurred()
        store.select(index: index)
    }

    private func activate(_ target: BrowserLaunchTarget, at index: Int) {
        store.select(index: index)
        onSelect(target, store.effectiveRememberingSelection)
    }
}

private func scrollSelectionToVisibleTarget(
    _ selectedID: String,
    orientation: BrowserPickerOrientation,
    proxy: ScrollViewProxy
) {
    if orientation == .horizontal {
        Task { @MainActor in
            await Task.yield()
            proxy.scrollTo(selectedID, anchor: .center)
        }
    } else {
        proxy.scrollTo(selectedID, anchor: .center)
    }
}

private struct VerticalPickerTargetButton: View {
    let target: BrowserLaunchTarget
    let index: Int
    let shortcut: PickerShortcut?
    let hintMode: BrowserPickerShortcutHintMode
    let isSelected: Bool
    let increasedContrast: Bool
    let action: () -> Void
    let hover: (CGPoint) -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(nsImage: target.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: BrowserPickerLayout.verticalIconSize, height: BrowserPickerLayout.verticalIconSize)
                    .accessibilityHidden(true)
                targetLabel(target, font: .callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(0)
                Spacer(minLength: 4)
                ShortcutHints(
                    shortcut: shortcut,
                    index: index,
                    mode: hintMode,
                    targetIdentifier: target.id
                )
                .fixedSize()
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: BrowserPickerLayout.verticalRowHeight)
            .contentShape(.rect)
            .background(selectionColor, in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(target.accessibilityLabel)
        .accessibilityValue("Shortcut hints: \(hintMode.displayName)")
        .accessibilityHint(shortcutAccessibilityHint(target: target, shortcut: shortcut, index: index))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(pickerAccessibilityIdentifier(for: target))
        .help(target.accessibilityLabel)
        .onContinuousHover { phase in
            if case .active = phase {
                hover(NSEvent.mouseLocation)
            }
        }
    }

    private var selectionColor: Color {
        isSelected ? Color.accentColor.opacity(increasedContrast ? 0.42 : 0.18) : .clear
    }
}

private struct HorizontalPickerTargetButton: View {
    let target: BrowserLaunchTarget
    let index: Int
    let shortcut: PickerShortcut?
    let hintMode: BrowserPickerShortcutHintMode
    let labelMode: BrowserPickerHorizontalLabelMode
    let isSelected: Bool
    let increasedContrast: Bool
    let action: () -> Void
    let hover: (CGPoint) -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                if hintMode != .hidden {
                    ShortcutHints(
                        shortcut: shortcut,
                        index: index,
                        mode: hintMode,
                        targetIdentifier: target.id
                    )
                    .frame(height: BrowserPickerLayout.horizontalHintHeight)
                }
                icon
                if labelMode == .all {
                    Text(verbatim: target.displayName)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(
                            width: BrowserPickerLayout.horizontalCellWidth,
                            height: BrowserPickerLayout.horizontalPerIconLabelHeight
                        )
                }
            }
            .frame(width: BrowserPickerLayout.horizontalCellWidth, height: cellHeight)
            .background(selectionColor, in: .rect(cornerRadius: 8))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(target.accessibilityLabel)
        .accessibilityValue(
            "Shortcut hints: \(hintMode.displayName), "
                + "Horizontal labels: \(labelMode.displayName)"
        )
        .accessibilityHint(shortcutAccessibilityHint(target: target, shortcut: shortcut, index: index))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(pickerAccessibilityIdentifier(for: target))
        .help(target.accessibilityLabel)
        .onContinuousHover { phase in
            if case .active = phase {
                hover(NSEvent.mouseLocation)
            }
        }
    }

    private var icon: some View {
        Image(nsImage: target.icon)
            .resizable()
            .scaledToFit()
            .frame(width: BrowserPickerLayout.horizontalIconSize, height: BrowserPickerLayout.horizontalIconSize)
            .overlay(alignment: .bottomTrailing) { badge }
            .accessibilityHidden(true)
    }

    @ViewBuilder private var badge: some View {
        switch target.kind {
        case .standard:
            EmptyView()
        case .profile:
            badgeImage("person.crop.circle.fill")
        case .privateWindow:
            badgeImage("eye.slash.fill")
        }
    }

    private func badgeImage(_ name: String) -> some View {
        Image(systemName: name)
            .font(.caption2)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.primary, Color(nsColor: .controlBackgroundColor))
            .padding(1)
            .background(.background, in: .circle)
            .accessibilityHidden(true)
    }

    private var cellHeight: CGFloat {
        (hintMode == .hidden ? 0 : BrowserPickerLayout.horizontalHintHeight)
            + BrowserPickerLayout.horizontalIconHeight
            + (labelMode == .all ? BrowserPickerLayout.horizontalPerIconLabelHeight : 0)
    }

    private var selectionColor: Color {
        isSelected ? Color.accentColor.opacity(increasedContrast ? 0.42 : 0.18) : .clear
    }
}

private struct ShortcutHints: View {
    let shortcut: PickerShortcut?
    let index: Int
    let mode: BrowserPickerShortcutHintMode
    let targetIdentifier: String

    var body: some View {
        HStack(spacing: 5) {
            if mode == .all || mode == .lettersOnly, let shortcut {
                Text(verbatim: shortcut.displayValue)
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: .rect(cornerRadius: 4))
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.pickerShortcutLetter(
                            targetIdentifier: targetIdentifier
                        )
                    )
            }
            if mode == .all || mode == .numbersOnly, index < 9 {
                Text(verbatim: "\(index + 1)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.pickerShortcutNumber(
                            targetIdentifier: targetIdentifier
                        )
                    )
            }
        }
        .accessibilityHidden(true)
    }
}

private extension View {
    @ViewBuilder
    func applyNumericShortcut(index: Int) -> some View {
        if index < 9 {
            keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])
        } else {
            self
        }
    }
}

private func targetLabel(_ target: BrowserLaunchTarget, font: Font) -> Text {
    var label = Text(verbatim: target.displayName)
        .font(font)
        .foregroundStyle(.primary)
    if let detail = target.detail {
        // SwiftUI.Text supports concatenation with +, but not +=.
        // swiftlint:disable:next shorthand_operator
        label = label + Text(verbatim: " · \(detail)")
            .font(font)
            .foregroundStyle(.secondary)
    }
    return label
}

private func shortcutAccessibilityHint(
    target _: BrowserLaunchTarget,
    shortcut: PickerShortcut?,
    index: Int
) -> String {
    let letter = shortcut?.displayValue
    let number = index < 9 ? String(index + 1) : nil
    let shortcuts = [letter, number].compactMap(\.self)
    return shortcuts.isEmpty
        ? "Opens the requested URL in this browser."
        : "Shortcuts \(shortcuts.joined(separator: " or "))."
}

private func pickerAccessibilityIdentifier(for target: BrowserLaunchTarget) -> String {
    switch target.kind {
    case .standard:
        AccessibilityIdentifier.pickerBrowser(bundleIdentifier: target.browser.browser.bundleIdentifier)
    case .privateWindow, .profile:
        AccessibilityIdentifier.pickerTarget(identifier: target.id)
    }
}

// swiftlint:enable file_length
