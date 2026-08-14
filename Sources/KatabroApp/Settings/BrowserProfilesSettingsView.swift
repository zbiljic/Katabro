import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BrowserProfilesSettingsView: View {
    let browsers: [BrowserApplication]
    let profileStore: BrowserProfileStore
    let userScriptBridge: UserScriptBridge
    let allowsConfiguration: Bool

    @State private var browserAwaitingDirectory: BrowserApplication?
    @State private var errorMessage: String?
    @State private var launcherHelperSetupMode: LauncherHelperSetupMode?

    private var supportedBrowsers: [BrowserApplication] {
        browsers.filter {
            BrowserProfileSupport.support(
                for: $0.browser.bundleIdentifier
            ) != nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profiles & Private Windows")
                .font(.headline)

            Text(
                "Katabro stays sandboxed. To pass private-window and profile arguments, "
                    + "install its small open.sh helper in the Application Scripts folder. "
                    + "Profile folders are read only after you choose them."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Label(
                    helperStatusLabel,
                    systemImage: helperStatusImage
                )
                .foregroundStyle(helperStatusColor)

                Spacer()

                Button(helperActionLabel) {
                    launcherHelperSetupMode = userScriptBridge.isInstalled
                        ? .replace
                        : .install
                }
                .disabled(!allowsConfiguration)
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsProfileScriptSetup
                )
            }

            if supportedBrowsers.isEmpty {
                Text("Install Chrome, Firefox, or another supported Chromium browser to enable profiles.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(supportedBrowsers) { browser in
                    profileBrowserRow(browser)
                }
            }
        }
        .fileImporter(
            isPresented: Binding(
                get: { browserAwaitingDirectory != nil },
                set: { isPresented in
                    if !isPresented {
                        browserAwaitingDirectory = nil
                    }
                }
            ),
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard let browser = browserAwaitingDirectory else {
                return
            }
            browserAwaitingDirectory = nil

            do {
                let urls = try result.get()
                guard let directory = urls.first else {
                    return
                }
                try profileStore.grantAccess(
                    to: directory,
                    for: browser
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .fileDialogMessage("Choose the browser data folder shown in Settings.")
        .fileDialogConfirmationLabel("Allow Profile Access")
        .sheet(item: $launcherHelperSetupMode) { mode in
            LauncherHelperSetupView(
                userScriptBridge: userScriptBridge,
                mode: mode
            )
        }
        .alert(
            "Profile Setup Failed",
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
        .task(id: browsers.map(\.id)) {
            for browser in supportedBrowsers {
                profileStore.refresh(for: browser)
            }
            userScriptBridge.refresh()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            userScriptBridge.refresh()
        }
    }

    private var helperStatusLabel: String {
        switch userScriptBridge.installationState {
        case .missing:
            "Launcher helper not installed"
        case .current:
            "Current launcher helper installed"
        case .custom:
            "Custom or older launcher helper installed"
        }
    }

    private var helperStatusImage: String {
        switch userScriptBridge.installationState {
        case .current:
            "checkmark.circle.fill"
        case .missing, .custom:
            "exclamationmark.circle"
        }
    }

    private var helperStatusColor: Color {
        switch userScriptBridge.installationState {
        case .current:
            .green
        case .custom:
            .orange
        case .missing:
            .secondary
        }
    }

    private var helperActionLabel: String {
        switch userScriptBridge.installationState {
        case .missing:
            "Set Up…"
        case .current:
            "Replace…"
        case .custom:
            "Replace with Current Version…"
        }
    }

    private func profileBrowserRow(
        _ browser: BrowserApplication
    ) -> some View {
        let profiles = profileStore.profiles(
            for: browser.browser.bundleIdentifier
        )
        let support = BrowserProfileSupport.support(
            for: browser.browser.bundleIdentifier
        )

        return HStack(alignment: .top, spacing: 10) {
            Image(nsImage: browser.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(browser.browser.displayName)

                if profiles.isEmpty {
                    Text(profileStore.error(for: browser.browser.bundleIdentifier) ?? support?.suggestedDirectory ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text(
                        "\(profiles.count) profile\(profiles.count == 1 ? "" : "s"): \(profiles.map(\.displayName).joined(separator: ", "))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                }
            }

            Spacer()

            if profileStore.isAuthorized(for: browser.browser.bundleIdentifier) {
                Button("Remove") {
                    profileStore.removeAccess(
                        for: browser.browser.bundleIdentifier
                    )
                }
                .disabled(!allowsConfiguration)
            } else {
                Button("Choose Folder…") {
                    browserAwaitingDirectory = browser
                }
                .disabled(!allowsConfiguration)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            AccessibilityIdentifier.settingsProfileBrowser(
                bundleIdentifier: browser.browser.bundleIdentifier
            )
        )
    }
}
