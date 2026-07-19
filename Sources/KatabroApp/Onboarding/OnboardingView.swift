import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss)
    private var dismiss

    let defaultBrowserClient: DefaultBrowserClient
    let preferencesStore: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 38))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Welcome to Katabro")
                        .font(.title2.bold())

                    Text("Choose a browser every time you open a web link.")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                setupStep(
                    number: 1,
                    title: "Make Katabro your default browser",
                    detail: "macOS may ask you to confirm changes for both HTTP and HTTPS links."
                )

                setupStep(
                    number: 2,
                    title: "Open any web link",
                    detail: "Katabro shows the browser picker near the pointer."
                )

                setupStep(
                    number: 3,
                    title: "Choose with the mouse or keyboard",
                    detail: "Use the arrow keys and Return, or press a displayed number."
                )
            }

            statusView

            if let lastError = defaultBrowserClient.lastError {
                Label(lastError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            HStack {
                Button("Use Katabro as Default Browser…") {
                    Task {
                        await defaultBrowserClient.requestDefaultBrowser()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(defaultBrowserClient.isRequesting)

                if defaultBrowserClient.isRequesting {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                Button("Done") {
                    preferencesStore.completeOnboarding()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
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
    }

    private func setupStep(
        number: Int,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .frame(width: 28, height: 28)
                .background(.quaternary, in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
