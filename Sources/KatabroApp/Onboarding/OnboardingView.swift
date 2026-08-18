import AppKit
import SwiftUI

struct OnboardingView: View {
    let defaultBrowserClient: DefaultBrowserClient
    let preferencesStore: PreferencesStore
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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

            VStack(alignment: .leading, spacing: 8) {
                Text(
                    "Katabro becomes your system default browser so it can receive web links."
                )

                Text(
                    "Choose where links open, or remember a browser for a specific website."
                )
            }
            .foregroundStyle(.secondary)

            statusView

            if let lastError = defaultBrowserClient.lastError {
                Label(lastError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.onboardingDefaultBrowserError
                    )
            }

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

                Button("Done") {
                    preferencesStore.completeOnboarding()
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(
                    AccessibilityIdentifier.onboardingDone
                )
            }
        }
        .padding(24)
        .frame(width: 520)
        .task {
            defaultBrowserClient.refresh()
        }
    }

    private var statusView: some View {
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
    }
}
