import AppKit
import SwiftUI

private enum OnboardingStep: CaseIterable, Equatable {
    case defaultBrowser
    case clipboardShortcut

    var previous: Self? {
        switch self {
        case .defaultBrowser: nil
        case .clipboardShortcut: .defaultBrowser
        }
    }

    var next: Self? {
        switch self {
        case .defaultBrowser: .clipboardShortcut
        case .clipboardShortcut: nil
        }
    }

    var progressText: String {
        switch self {
        case .defaultBrowser: "Step 1 of 2"
        case .clipboardShortcut: "Step 2 of 2"
        }
    }
}

struct OnboardingView: View {
    let defaultBrowserClient: DefaultBrowserClient
    let preferencesStore: PreferencesStore
    let clipboardURLShortcutSettings: GlobalShortcutSettings
    let onDone: () -> Void

    @State private var step = OnboardingStep.defaultBrowser

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Welcome to Katabro")
                        .font(.title2.bold())

                    Text("Choose a browser every time you open a web link.")
                        .foregroundStyle(.secondary)
                }
            }

            Text(step.progressText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(
                    AccessibilityIdentifier.onboardingStepProgress
                )

            switch step {
            case .defaultBrowser:
                DefaultBrowserOnboardingStep(
                    defaultBrowserClient: defaultBrowserClient,
                    onContinue: advance
                )
            case .clipboardShortcut:
                ClipboardShortcutOnboardingStep(
                    settings: clipboardURLShortcutSettings,
                    onBack: goBack,
                    onDone: finish
                )
            }
        }
        .padding(24)
        .frame(width: 520, height: 360)
        .task {
            defaultBrowserClient.refresh()
        }
    }

    private func advance() {
        guard let next = step.next else { return }
        step = next
    }

    private func goBack() {
        guard let previous = step.previous else { return }
        step = previous
    }

    private func finish() {
        preferencesStore.completeOnboarding()
        onDone()
    }
}

private struct DefaultBrowserOnboardingStep: View {
    let defaultBrowserClient: DefaultBrowserClient
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Set Up Katabro")
                .font(.title3.bold())
                .accessibilityIdentifier(
                    AccessibilityIdentifier.onboardingDefaultBrowserStep
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(
                    "Katabro becomes your system default browser so it can receive web links."
                )

                Text(
                    "Choose where links open, or remember a browser for a specific website."
                )
            }
            .foregroundStyle(.secondary)

            Label(
                defaultBrowserClient.statusDescription,
                systemImage: defaultBrowserClient.status == .current
                    ? "checkmark.circle.fill"
                    : "info.circle"
            )
            .foregroundStyle(
                defaultBrowserClient.status == .current ? .green : .secondary
            )
            .accessibilityLabel(
                "Default browser status: \(defaultBrowserClient.statusDescription)"
            )
            .accessibilityIdentifier(
                AccessibilityIdentifier.onboardingDefaultBrowserStatus
            )

            if let lastError = defaultBrowserClient.lastError {
                Label(lastError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.onboardingDefaultBrowserError
                    )
            }

            Spacer(minLength: 0)

            HStack {
                if defaultBrowserClient.status != .current {
                    Button("Use Katabro as Default Browser…") {
                        Task {
                            await defaultBrowserClient.requestDefaultBrowser()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(defaultBrowserClient.isRequesting)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.onboardingDefaultBrowserAction
                    )

                    if defaultBrowserClient.isRequesting {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Spacer()

                Button("Continue", action: onContinue)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.onboardingContinue
                    )
            }
        }
    }
}

private struct ClipboardShortcutOnboardingStep: View {
    let settings: GlobalShortcutSettings
    let onBack: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Open Copied Links Faster")
                .font(.title3.bold())
                .accessibilityIdentifier(
                    AccessibilityIdentifier.onboardingClipboardShortcutStep
                )

            Text(
                "Copy a web address, then press the shortcut to open it through Katabro."
            )
            .foregroundStyle(.secondary)

            Text("Optional. The shortcut stays on this Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)

            GlobalShortcutSettingsRow(
                settings: settings,
                toggleAccessibilityIdentifier: AccessibilityIdentifier.onboardingClipboardShortcutToggle,
                fieldAccessibilityIdentifier: AccessibilityIdentifier.onboardingClipboardShortcutField,
                statusAccessibilityIdentifier: AccessibilityIdentifier.onboardingClipboardShortcutStatus,
                accessibilityHelp: "Click, then press the global Open URL from Clipboard shortcut. "
                    + "Use at least two modifier keys. Press Escape to cancel."
            )

            Spacer(minLength: 0)

            HStack {
                Button("Back", action: onBack)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.onboardingBack
                    )

                Spacer()

                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.onboardingDone
                    )
            }
        }
    }
}
