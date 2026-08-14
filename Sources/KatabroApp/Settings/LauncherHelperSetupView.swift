import SwiftUI

enum LauncherHelperSetupMode: String, Identifiable {
    case install
    case replace

    var id: Self {
        self
    }
}

struct LauncherHelperSetupView: View {
    @Environment(\.dismiss)
    private var dismiss

    let userScriptBridge: UserScriptBridge
    let mode: LauncherHelperSetupMode

    @State private var errorMessage: String?
    @State private var installationCompleted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if showsInstalledConfirmation {
                installedContent
            } else {
                installationContent
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(
                    userScriptBridge.isInstalled
                        && mode == .install
                        ? .defaultAction
                        : .cancelAction
                )
            }
        }
        .padding(24)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .task {
            userScriptBridge.refresh()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            userScriptBridge.refresh()
        }
        .alert(
            "Launcher Helper Setup Failed",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "terminal.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(mode == .replace ? "Replace Launcher Helper" : "Install Launcher Helper")
                    .font(.headline)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.settingsProfileScriptSheet
                    )
                Text(
                    mode == .replace
                        ? "Install a fresh copy of open.sh"
                        : "Required for private windows and browser profiles"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var installedContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Launcher helper installed")
                    .font(.headline)
                Text("Private windows and configured browser profiles are ready to use.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(
            AccessibilityIdentifier.settingsProfileScriptInstalled
        )
    }

    private var installationContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(
                mode == .replace
                    ? "Replace the existing helper with Katabro’s current version. "
                    + "macOS will ask you to confirm the file."
                    : "Install Katabro’s small launcher helper. macOS will ask you to confirm where it is saved."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()

                Button(mode == .replace ? "Replace open.sh…" : "Install open.sh…") {
                    installScript()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsProfileScriptInstall
                )
            }
        }
    }

    private var showsInstalledConfirmation: Bool {
        installationCompleted || (mode == .install && userScriptBridge.isInstalled)
    }

    private func installScript() {
        do {
            installationCompleted = try userScriptBridge.installScript()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
