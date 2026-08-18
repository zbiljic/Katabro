import SwiftUI

struct PickerSettingsView: View {
    let preferencesStore: PreferencesStore
    let onPreviewPicker: () -> Void

    var body: some View {
        @Bindable var preferencesStore = preferencesStore

        Form {
            Section("Layout") {
                Picker("Orientation", selection: orientationBinding) {
                    ForEach(BrowserPickerOrientation.allCases, id: \.self) { orientation in
                        Text(orientation.displayName).tag(orientation)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(AccessibilityIdentifier.settingsPickerOrientation)

                Picker("Vertical width", selection: verticalWidthBinding) {
                    ForEach(BrowserPickerVerticalWidth.allCases, id: \.self) { width in
                        Text(width.displayName).tag(width)
                    }
                }
                .pickerStyle(.menu)
                .disabled(preferencesStore.pickerPreferences.orientation == .horizontal)
                .accessibilityHint("Applies to Vertical orientation.")
                .accessibilityIdentifier(AccessibilityIdentifier.settingsPickerVerticalWidth)

                Stepper(
                    "Visible choices: \(preferencesStore.pickerPreferences.visibleChoiceCount)",
                    value: visibleChoiceCountBinding,
                    in: BrowserPickerPreferences.visibleChoiceRange
                )
                .accessibilityIdentifier(AccessibilityIdentifier.settingsPickerVisibleChoices)
            }

            Section {
                Picker("Destination", selection: destinationBinding) {
                    ForEach(BrowserPickerDestinationDisplay.allCases, id: \.self) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier(AccessibilityIdentifier.settingsPickerDestination)

                VStack(alignment: .leading, spacing: 4) {
                    Picker("Shortcut hints", selection: shortcutHintBinding) {
                        ForEach(BrowserPickerShortcutHintMode.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier(AccessibilityIdentifier.settingsPickerShortcutHints)

                    if preferencesStore.pickerPreferences.shortcutHintMode == .hidden {
                        Text("Keyboard shortcuts remain active.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier(
                                AccessibilityIdentifier.settingsPickerShortcutHintsHiddenNote
                            )
                    }
                }

                Picker("Horizontal labels", selection: horizontalLabelBinding) {
                    ForEach(BrowserPickerHorizontalLabelMode.allCases, id: \.self) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .disabled(preferencesStore.pickerPreferences.orientation == .vertical)
                .accessibilityHint("Applies to Horizontal orientation.")
                .accessibilityIdentifier(AccessibilityIdentifier.settingsPickerHorizontalLabels)

                Toggle("Show Remember option", isOn: showsRememberBinding)
                    .accessibilityIdentifier(AccessibilityIdentifier.settingsPickerShowRemember)
            } header: {
                Text("Information")
            }

            Section {} footer: {
                Button("Preview Picker", action: onPreviewPicker)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(AccessibilityIdentifier.settingsPickerPreview)
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(AccessibilityIdentifier.settingsPickerForm)
    }

    private var orientationBinding: Binding<BrowserPickerOrientation> {
        preferenceBinding(\.orientation)
    }

    private var visibleChoiceCountBinding: Binding<Int> {
        preferenceBinding(\.visibleChoiceCount)
    }

    private var verticalWidthBinding: Binding<BrowserPickerVerticalWidth> {
        preferenceBinding(\.verticalWidth)
    }

    private var destinationBinding: Binding<BrowserPickerDestinationDisplay> {
        preferenceBinding(\.destinationDisplay)
    }

    private var shortcutHintBinding: Binding<BrowserPickerShortcutHintMode> {
        preferenceBinding(\.shortcutHintMode)
    }

    private var horizontalLabelBinding: Binding<BrowserPickerHorizontalLabelMode> {
        preferenceBinding(\.horizontalLabelMode)
    }

    private var showsRememberBinding: Binding<Bool> {
        preferenceBinding(\.showsRememberChoice)
    }

    private func preferenceBinding<Value>(
        _ keyPath: WritableKeyPath<BrowserPickerPreferences, Value>
    ) -> Binding<Value> {
        Binding(
            get: { preferencesStore.pickerPreferences[keyPath: keyPath] },
            set: { value in
                var preferences = preferencesStore.pickerPreferences
                preferences[keyPath: keyPath] = value
                preferencesStore.setPickerPreferences(preferences)
            }
        )
    }
}
