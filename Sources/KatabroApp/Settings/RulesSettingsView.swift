import KatabroCore
import SwiftUI

struct RulesSettingsView: View {
    let preferencesStore: PreferencesStore

    @State private var isConfirmingRemoveAll = false

    var body: some View {
        Form {
            if preferencesStore.exactHostRoutingRules.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Rules",
                        systemImage: "arrow.triangle.branch",
                        description: Text(
                            "Create an exact-host rule by selecting “Remember this choice…” in the browser picker."
                        )
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.settingsRulesEmpty
                    )
                }
            } else {
                Section("Exact Hosts") {
                    ForEach(preferencesStore.exactHostRoutingRules) { rule in
                        RulesSettingsRow(rule: rule) {
                            preferencesStore.removeExactHostRoutingRule(
                                host: rule.host
                            )
                        }
                    }
                }

                Section {
                    Button("Remove All…", role: .destructive) {
                        isConfirmingRemoveAll = true
                    }
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.settingsRulesRemoveAll
                    )
                }
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(
            AccessibilityIdentifier.settingsRulesForm
        )
        .confirmationDialog(
            "Remove all exact-host rules?",
            isPresented: $isConfirmingRemoveAll
        ) {
            Button("Remove All", role: .destructive) {
                preferencesStore.removeAllExactHostRoutingRules()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Links will return to showing the browser picker.")
        }
    }
}

private struct RulesSettingsRow: View {
    let rule: ExactHostRoutingRule
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.host)

                Text(rule.targetIdentifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .privacySensitive()
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                onRemove()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove rule for \(rule.host)")
            .accessibilityIdentifier(
                AccessibilityIdentifier.settingsRuleRemove(
                    host: rule.host
                )
            )
            .help("Remove rule for \(rule.host)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            AccessibilityIdentifier.settingsRule(host: rule.host)
        )
    }
}

#if DEBUG
    #Preview("Rules — Populated") {
        RulesSettingsView(
            preferencesStore: PreferencesStore(
                initialPreferences: AppPreferences(
                    exactHostRoutingRules: [
                        ExactHostRoutingRule(
                            host: "example.com",
                            targetIdentifier: "com.example.browser"
                        ),
                    ].compactMap(\.self)
                )
            )
        )
        .frame(width: 560, height: 560)
    }

    #Preview("Rules — Empty") {
        RulesSettingsView(preferencesStore: PreferencesStore())
            .frame(width: 560, height: 560)
    }
#endif
