import KatabroCore
import SwiftUI

struct RulesSettingsView: View {
    let preferencesStore: PreferencesStore
    let routingDecisionLogStore: RoutingDecisionLogStore

    @State private var isConfirmingRemoveAll = false
    @State private var isConfirmingRuleAction = false
    @State private var isShowingAllRecentRoutes = false
    @State private var pendingRuleAction: PendingRuleAction?

    var body: some View {
        Form {
            recentRoutesSection

            if preferencesStore.exactHostRoutingRules.isEmpty {
                Section("Exact Hosts") {
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
        .confirmationDialog(
            pendingRuleAction?.title ?? "Create exact-host rule?",
            isPresented: $isConfirmingRuleAction
        ) {
            if let pendingRuleAction {
                Button(pendingRuleAction.confirmationLabel) {
                    apply(pendingRuleAction)
                }
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsRecentRoutesRuleConfirm
                )
            }
            Button("Cancel", role: .cancel) {
                pendingRuleAction = nil
            }
            .accessibilityIdentifier(
                AccessibilityIdentifier.settingsRecentRoutesRuleCancel
            )
        } message: {
            if let pendingRuleAction {
                Text(pendingRuleAction.message)
            }
        }
        .onChange(of: routingDecisionLogStore.entries.isEmpty) {
            if routingDecisionLogStore.entries.isEmpty {
                isShowingAllRecentRoutes = false
            }
        }
    }

    private var recentRoutesSection: some View {
        Section {
            HStack {
                Text("Recent Routes")
                    .font(.headline)

                Spacer()

                Button("Clear", action: clearRecentRoutes)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(routingDecisionLogStore.entries.isEmpty)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.settingsRecentRoutesClear
                    )
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(
                AccessibilityIdentifier.settingsRecentRoutesSection
            )

            if routingDecisionLogStore.entries.isEmpty {
                Text("No recent routes yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.settingsRecentRoutesEmpty
                    )
            } else {
                ForEach(displayedRecentRoutes) { entry in
                    RecentRouteRow(
                        entry: entry,
                        isExpanded: isShowingAllRecentRoutes,
                        ruleAvailability: ruleAvailability(for: entry),
                        onRequestRuleAction: requestRuleAction
                    )
                }

                if routingDecisionLogStore.entries.count > 3 {
                    Button(
                        isShowingAllRecentRoutes
                            ? "Show Less"
                            : "Show All (\(routingDecisionLogStore.entries.count))…"
                    ) {
                        isShowingAllRecentRoutes.toggle()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .accessibilityIdentifier(
                        isShowingAllRecentRoutes
                            ? AccessibilityIdentifier.settingsRecentRoutesShowLess
                            : AccessibilityIdentifier.settingsRecentRoutesShowAll
                    )
                }
            }
        } footer: {
            Text("Hostnames only. Kept in memory until you quit.")
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsRecentRoutesPrivacy
                )
        }
    }

    private var displayedRecentRoutes: [RoutingDecisionLogEntry] {
        if isShowingAllRecentRoutes {
            return Array(routingDecisionLogStore.entries.reversed())
        }

        return Array(routingDecisionLogStore.entries.suffix(3).reversed())
    }

    private func ruleAvailability(
        for entry: RoutingDecisionLogEntry
    ) -> RecentRouteRuleAvailability {
        guard let candidate = entry.ruleCandidate else {
            return .unavailable
        }

        guard
            let existingRule = preferencesStore.exactHostRoutingRules.first(
                where: { $0.host == candidate.host }
            )
        else {
            return .create(candidate)
        }

        if existingRule.targetIdentifier == candidate.targetIdentifier {
            return .alreadyExists
        }

        return .replace(candidate)
    }

    private func requestRuleAction(
        _ pendingRuleAction: PendingRuleAction
    ) {
        self.pendingRuleAction = pendingRuleAction
        isConfirmingRuleAction = true
    }

    private func apply(
        _ pendingRuleAction: PendingRuleAction
    ) {
        preferencesStore.setExactHostRoutingRule(
            for: pendingRuleAction.candidate.destination,
            targetIdentifier: pendingRuleAction.candidate.targetIdentifier
        )
        self.pendingRuleAction = nil
    }

    private func clearRecentRoutes() {
        isShowingAllRecentRoutes = false
        pendingRuleAction = nil
        routingDecisionLogStore.clear()
    }
}

private enum RecentRouteRuleAvailability {
    case unavailable
    case create(RoutingDecisionLogEntry.RuleCandidate)
    case replace(RoutingDecisionLogEntry.RuleCandidate)
    case alreadyExists
}

private struct PendingRuleAction {
    enum Kind {
        case create
        case replace
    }

    let kind: Kind
    let candidate: RoutingDecisionLogEntry.RuleCandidate

    var title: String {
        switch kind {
        case .create:
            "Always open links to \(candidate.host) in \(candidate.targetDisplayLabel)?"
        case .replace:
            "Replace rule for \(candidate.host)?"
        }
    }

    var message: String {
        switch kind {
        case .create:
            "Katabro will use this target for future links to \(candidate.host)."
        case .replace:
            "The existing rule for \(candidate.host) will be replaced with \(candidate.targetDisplayLabel)."
        }
    }

    var confirmationLabel: String {
        switch kind {
        case .create:
            "Create Rule"
        case .replace:
            "Replace Rule"
        }
    }
}

private struct RecentRouteRow: View {
    let entry: RoutingDecisionLogEntry
    let isExpanded: Bool
    let ruleAvailability: RecentRouteRuleAvailability
    let onRequestRuleAction: (PendingRuleAction) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(entry.destinationDisplayName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(entry.receivedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text("\(entry.sourceDisplayName) · \(entry.decision.summary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(entry.result.summary)

                    if let targetDisplayLabel = entry.targetDisplayLabel {
                        Text("·")
                        Text(targetDisplayLabel)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ruleAction
        }
        .padding(.vertical, 1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            isExpanded
                ? AccessibilityIdentifier.settingsRecentRouteExpandedRow(
                    requestID: entry.id.uuidString.lowercased()
                )
                : AccessibilityIdentifier.settingsRecentRoutePreviewRow(
                    requestID: entry.id.uuidString.lowercased()
                )
        )
    }

    @ViewBuilder private var ruleAction: some View {
        switch ruleAvailability {
        case .unavailable:
            EmptyView()
        case let .create(candidate):
            Button("Create Rule…") {
                onRequestRuleAction(
                    PendingRuleAction(
                        kind: .create,
                        candidate: candidate
                    )
                )
            }
            .controlSize(.small)
            .accessibilityIdentifier(
                AccessibilityIdentifier.settingsRecentRouteRuleAction(
                    requestID: entry.id.uuidString.lowercased()
                )
            )
        case let .replace(candidate):
            Button("Replace Rule…") {
                onRequestRuleAction(
                    PendingRuleAction(
                        kind: .replace,
                        candidate: candidate
                    )
                )
            }
            .controlSize(.small)
            .accessibilityIdentifier(
                AccessibilityIdentifier.settingsRecentRouteRuleAction(
                    requestID: entry.id.uuidString.lowercased()
                )
            )
        case .alreadyExists:
            Text("Rule already exists")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsRecentRouteRuleExists(
                        requestID: entry.id.uuidString.lowercased()
                    )
                )
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
            ),
            routingDecisionLogStore: RoutingDecisionLogStore()
        )
        .frame(width: 560, height: 560)
    }

    #Preview("Rules — Empty") {
        RulesSettingsView(
            preferencesStore: PreferencesStore(),
            routingDecisionLogStore: RoutingDecisionLogStore()
        )
        .frame(width: 560, height: 560)
    }
#endif
