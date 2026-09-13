import AppKit
import KatabroCore
import SwiftUI

// swiftlint:disable attributes multiline_function_chains opening_brace

struct ScreenURLPickerView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @FocusState private var isFocused: Bool
    @State private var hoverSelectionArbitrator = PointerHoverSelectionArbitrator()

    let store: ScreenURLPickerStore
    let onSelect: (ScreenURLPickerStore.Selection) -> Void
    let onCancel: () -> Void
    var onOpenScreenRecordingSettings: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("URLs Found on Screen").font(.headline)
            content
            footer
        }
        .padding(16)
        .frame(width: 420, alignment: .topLeading)
        .background {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).stroke(
                colorSchemeContrast == .increased ? Color.primary : Color.secondary.opacity(0.3)
            )
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .defaultFocus($isFocused, true)
        .onKeyPress(.upArrow) { moveSelectionFromKeyboard(by: -1); return .handled }
        .onKeyPress(.downArrow) { moveSelectionFromKeyboard(by: 1); return .handled }
        .onKeyPress(.return) { activateSelection() }
        .onKeyPress(.space) { activateSelection() }
        .onKeyPress(.escape) { onCancel(); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "0"), phases: .down) { _ in
            selectOpenAllFromKeyboard(); return .handled
        }
        .onKeyPress(characters: .decimalDigits, phases: .down) { press in
            guard let value = Int(press.characters), value > 0 else { return .ignored }
            let index = value - 1
            guard store.results.indices.contains(index) else { return .ignored }
            store.select(index: index)
            onSelect(.url(index))
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifier.screenURLPicker)
    }

    @ViewBuilder private var content: some View {
        switch store.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                .accessibilityIdentifier(AccessibilityIdentifier.screenURLLoadingState)
        case .results:
            VStack(spacing: 8) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(store.results.enumerated()), id: \.element.id) { index, detected in
                                urlRow(detected, index: index).id(detected.id)
                            }
                        }
                    }
                    .frame(maxHeight: 5 * 50)
                    .onChange(of: store.selection) { _, selection in
                        if
                            case let .url(index) = selection,
                            store.results.indices
                                .contains(index)
                        {
                            proxy.scrollTo(store.results[index].id)
                        }
                    }
                }
                if store.supportsOpenAll {
                    Divider(); openAllRow
                }
            }
        case .empty:
            unavailable(
                "No Web URLs Found",
                description: "Try again with the link larger or clearer",
                accessibilityIdentifier: AccessibilityIdentifier.screenURLEmptyState
            )
        case .permissionRequired:
            permissionRequired
        case .captureFailed:
            unavailable(
                "Couldn’t Capture Screen",
                description: "Try again in a moment.",
                accessibilityIdentifier: AccessibilityIdentifier.screenURLCaptureFailureState
            )
        case .visionUnavailable:
            unavailable(
                "On-device Text Recognition Unavailable",
                description: "Apple Vision text recognition is unavailable on this Mac.",
                accessibilityIdentifier: AccessibilityIdentifier.screenURLVisionUnavailableState
            )
        }
    }

    private func urlRow(_ detected: DetectedURL, index: Int) -> some View {
        let selected = store.selection == .url(index)
        return Button { onSelect(.url(index)) } label: {
            HStack(spacing: 8) {
                Image(systemName: "link")
                VStack(alignment: .leading, spacing: 2) {
                    Text(ExactHostRoutingRule.normalizedHost(detected.destination.url.host() ?? "")
                        ?? detected.destination.url.host() ?? detected.destination.url.absoluteString).font(.body)
                    Text(verbatim: detected.destination.url.absoluteString).font(.caption.monospaced())
                        .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                if index < 9 {
                    Color.clear.frame(width: 8).accessibilityHidden(true)
                }
            }
            .padding(8)
            .contentShape(.rect)
            .background(selected ? Color.accentColor.opacity(0.2) : .clear, in: .rect(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onContinuousHover { phase in
            if case .active = phase {
                selectURLFromHover(index: index, pointerPosition: NSEvent.mouseLocation)
            }
        }
        .accessibilityLabel("Open detected URL \(detected.destination.url.absoluteString)")
        .accessibilityValue(detected.destination.url.absoluteString)
        .accessibilityHint(index < 9 ? "Press \(index + 1) to open." : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(detected.destination.url.absoluteString)
        .accessibilityIdentifier(AccessibilityIdentifier.screenURLRow(index))
        .overlay(alignment: .trailing) {
            if index < 9 {
                Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .padding(.trailing, 8).allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityLabel("Keyboard shortcut \(index + 1)")
                    .accessibilityIdentifier(AccessibilityIdentifier.screenURLShortcut(index))
            }
        }
    }

    private var openAllRow: some View {
        Button { onSelect(.all) } label: {
            HStack {
                Image(systemName: "link.badge.plus"); VStack(alignment: .leading) {
                    Text("Open all \(store.results.count) URLs"); Text("Route all in visual order").font(.caption)
                        .foregroundStyle(.secondary)
                }; Spacer(); Text("0").font(.caption).foregroundStyle(.secondary)
            }
            .padding(8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(store.selection == .all ? Color.accentColor.opacity(0.2) : .clear, in: .rect(cornerRadius: 7))
        .onContinuousHover { phase in
            if case .active = phase {
                selectOpenAllFromHover(pointerPosition: NSEvent.mouseLocation)
            }
        }
        .accessibilityLabel("Open all \(store.results.count) detected URLs")
        .accessibilityHint("Press 0 to select, then Return to open.")
        .accessibilityValue(store.selection == .all ? "Selected" : "Not selected")
        .accessibilityAddTraits(store.selection == .all ? .isSelected : [])
        .accessibilityIdentifier(AccessibilityIdentifier.screenURLOpenAll)
    }

    private var footer: some View {
        HStack { Text("Esc Cancel"); Spacer(); Text("↑↓ Select"); Text("↩ Open") }.font(.caption)
            .foregroundStyle(.secondary)
    }

    private var permissionRequired: some View {
        VStack(spacing: 12) {
            ContentUnavailableView(
                "Screen Recording Access Required",
                systemImage: "record.circle",
                description: Text("Allow Katabro in Privacy & Security, then capture again.")
            )
            .accessibilityIdentifier(AccessibilityIdentifier.screenURLPermissionState)
            Button("Open Screen Recording Settings…", action: onOpenScreenRecordingSettings)
                .accessibilityIdentifier(AccessibilityIdentifier.screenURLOpenSystemSettings)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private func unavailable(
        _ title: String,
        description: String,
        accessibilityIdentifier: String
    ) -> some View {
        ContentUnavailableView(title, systemImage: "link.badge.plus", description: Text(description)).frame(
            maxWidth: .infinity,
            minHeight: 120
        ).accessibilityIdentifier(accessibilityIdentifier)
    }

    private func activateSelection() -> KeyPress.Result {
        guard let selection = store.selection else { return .ignored }
        onSelect(selection)
        return .handled
    }

    private func moveSelectionFromKeyboard(by offset: Int) {
        hoverSelectionArbitrator.keyboardNavigationOccurred(at: NSEvent.mouseLocation)
        store.moveSelection(by: offset)
    }

    private func selectOpenAllFromKeyboard() {
        hoverSelectionArbitrator.keyboardNavigationOccurred(at: NSEvent.mouseLocation)
        store.selectOpenAll()
    }

    private func selectURLFromHover(index: Int, pointerPosition: CGPoint) {
        guard hoverSelectionArbitrator.shouldSelectForHover(at: pointerPosition) else { return }
        store.select(index: index)
    }

    private func selectOpenAllFromHover(pointerPosition: CGPoint) {
        guard hoverSelectionArbitrator.shouldSelectForHover(at: pointerPosition) else { return }
        store.selectOpenAll()
    }
}

// swiftlint:enable attributes multiline_function_chains opening_brace
