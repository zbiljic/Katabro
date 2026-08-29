import SwiftUI

struct GeneralSettingsView: View {
    static let folderUnavailableMessage = "Folder access is unavailable. Choose the folder again to recover."

    let defaultBrowserClient: DefaultBrowserClient
    let loginItemClient: LoginItemClient
    let clipboardURLShortcutSettings: GlobalShortcutSettings
    let screenURLCaptureSettings: ScreenURLCaptureSettings
    let screenCaptureClient: ScreenCaptureClient
    let visionURLRecognitionClient: VisionURLRecognitionClient
    let preferencesStore: PreferencesStore
    let configurationFolderClient: ConfigurationFolderClient
    @State private var showingFolderDisclosure = false
    @State private var showingFolderAdoption = false
    @State private var isChoosingFolder = false
    @State private var pendingFolderClient: FilePreferencesClient?
    @State private var pendingFolderSnapshot: BrowserSettingsSnapshot?
    @State private var pendingFolderBytes: Data?
    @State private var selectionError: String?

    var body: some View {
        Form {
            Section("Default Browser") {
                DefaultBrowserSettingsRow(
                    client: defaultBrowserClient
                )

                if let lastError = defaultBrowserClient.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .accessibilityIdentifier(
                            AccessibilityIdentifier.settingsDefaultBrowserError
                        )
                }
            }

            Section("Startup") {
                Toggle(
                    "Open Katabro at login",
                    isOn: Binding(
                        get: {
                            loginItemClient.isEnabled
                        },
                        set: { enabled in
                            loginItemClient.update(
                                enabled: enabled
                            )
                        }
                    )
                )
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsLoginItemToggle
                )

                Text(loginItemClient.statusDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.settingsLoginItemStatus
                    )

                if let lastError = loginItemClient.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .accessibilityIdentifier(
                            AccessibilityIdentifier.settingsLoginItemError
                        )
                }
            }

            ClipboardURLShortcutSettingsView(settings: clipboardURLShortcutSettings)

            ScreenURLCaptureSettingsView(
                settings: screenURLCaptureSettings,
                screenCaptureClient: screenCaptureClient,
                visionURLRecognitionClient: visionURLRecognitionClient
            )

            Section("Sync") {
                Picker(
                    "Browser Settings",
                    selection: Binding(
                        get: { preferencesStore.syncMethod },
                        set: { method in select(method) }
                    )
                ) {
                    ForEach(PreferencesStore.SyncMethod.allCases.filter {
                        $0 != .iCloud || preferencesStore.iCloudSyncAvailable
                    }, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .pickerStyle(.menu)
                .disabled(isChoosingFolder)
                .accessibilityIdentifier(AccessibilityIdentifier.settingsSyncMethod)

                LabeledContent("Browser Settings") {
                    Text(syncStatusDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel(syncStatusDescription)
                        .accessibilityValue(syncStatusDescription)
                        .accessibilityIdentifier(
                            AccessibilityIdentifier.settingsSyncStatus
                        )
                }

                if preferencesStore.syncMethod == .folder {
                    LabeledContent("Location") {
                        Text(folderLocation)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(folderLocation)
                            .accessibilityLabel(folderLocation)
                            .accessibilityValue(folderLocation)
                            .accessibilityIdentifier(AccessibilityIdentifier.settingsSyncFolderName)
                    }
                    Button("Choose Folder…") { showingFolderDisclosure = true }
                        .disabled(isChoosingFolder)
                        .accessibilityIdentifier(AccessibilityIdentifier.settingsSyncChooseFolder)
                    Button("Disconnect") { preferencesStore.setSyncMethod(.thisMac) }
                        .accessibilityIdentifier(AccessibilityIdentifier.settingsSyncDisconnect)
                }

                if let error = syncErrorDescription {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .accessibilityLabel(error)
                        .accessibilityIdentifier(AccessibilityIdentifier.settingsSyncError)
                }
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(
            AccessibilityIdentifier.settingsGeneralForm
        )
        .task {
            defaultBrowserClient.refresh()
            loginItemClient.refresh()
            screenURLCaptureSettings.refreshScreenCaptureAuthorization()
        }
        .confirmationDialog(
            "Sync exact-host rules with this folder?",
            isPresented: $showingFolderDisclosure,
            titleVisibility: .visible
        ) {
            Button("Continue") { chooseFolder() }
                .accessibilityIdentifier(AccessibilityIdentifier.settingsSyncDisclosureContinue)
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier(AccessibilityIdentifier.settingsSyncDisclosureCancel)
        } message: {
            Text(
                "Folder sync writes exact hostnames and routing target identifiers into the shared JSON file. "
                    + "Anyone with folder access can read them."
            )
        }
        .confirmationDialog(
            "Use settings from this folder?",
            isPresented: $showingFolderAdoption,
            titleVisibility: .visible
        ) {
            Button("Use Folder Settings") {
                if let client = pendingFolderClient, let snapshot = pendingFolderSnapshot {
                    guard
                        case let .snapshot(current, bytes) = client.read(),
                        current == snapshot,
                        bytes == pendingFolderBytes
                    else {
                        selectionError = "The shared settings changed before adoption. Choose the folder again."
                        pendingFolderClient = nil
                        pendingFolderSnapshot = nil
                        pendingFolderBytes = nil
                        return
                    }
                    if !preferencesStore.configureFolderSync(client: client, displayName: client.displayName) {
                        selectionError = "Folder access is unavailable. Choose the folder again to recover."
                    } else {
                        preferencesStore.applyBrowserSettingsSnapshot(snapshot)
                    }
                }
                pendingFolderClient = nil
                pendingFolderSnapshot = nil
                pendingFolderBytes = nil
            }
            .accessibilityIdentifier(AccessibilityIdentifier.settingsSyncAdopt)
            Button("Replace File with This Mac") {
                guard
                    let client = pendingFolderClient,
                    case .snapshot = client.read(),
                    client.write(preferencesStore.browserSettingsSnapshot())
                else {
                    selectionError = "The shared settings file could not be written."
                    pendingFolderClient = nil
                    pendingFolderSnapshot = nil
                    pendingFolderBytes = nil
                    return
                }
                if !preferencesStore.configureFolderSync(client: client, displayName: client.displayName) {
                    selectionError = "Folder access is unavailable. Choose the folder again to recover."
                }
                pendingFolderClient = nil
                pendingFolderSnapshot = nil
                pendingFolderBytes = nil
            }
            .accessibilityIdentifier(AccessibilityIdentifier.settingsSyncReplace)
            Button("Cancel", role: .cancel) {
                pendingFolderClient = nil
                pendingFolderSnapshot = nil
                pendingFolderBytes = nil
            }
            .accessibilityIdentifier(AccessibilityIdentifier.settingsSyncAdoptionCancel)
        }
    }

    private var syncStatusDescription: String {
        switch preferencesStore.syncMethod {
        case .thisMac:
            if preferencesStore.iCloudSelectionUnavailable {
                "iCloud is unavailable for this build; browser order and picker shortcuts stay on this Mac. "
                    + "Your iCloud selection is retained."
            } else {
                "Browser order, picker shortcuts, and exact-host rules stay on this Mac."
            }
        case .iCloud:
            switch preferencesStore.iCloudSyncStatus {
            case .available:
                "Browser order and picker shortcuts sync through iCloud. Exact-host rules stay on this Mac."
            case .localOnly:
                "Browser order and picker shortcuts stay on this Mac because iCloud sync is unavailable for this build."
            case .invalidCloudValue:
                "Some browser settings stay on this Mac because saved iCloud settings could not be read."
            }
        case .folder:
            switch preferencesStore.folderSyncStatus {
            case let .active(displayName):
                "Browser order, picker shortcuts, and exact-host rules sync through \(displayName)."
            case .missingFile:
                "The shared settings file is missing; local settings remain active."
            case .invalid:
                "The shared settings file is invalid; local settings remain active."
            case .unavailable, .lostAuthorization:
                "Folder sync is unavailable; local settings remain active."
            case .inactive:
                "Browser order, picker shortcuts, and exact-host rules sync through a folder."
            }
        }
    }

    private var folderLocation: String {
        if !preferencesStore.activeFolderLocation.isEmpty {
            return preferencesStore.activeFolderLocation
        }
        return "Unavailable"
    }

    private var syncErrorDescription: String? {
        if let selectionError {
            return selectionError
        }
        switch preferencesStore.folderSyncStatus {
        case .invalid:
            return "The shared settings file could not be read."
        case .unavailable, .lostAuthorization:
            return Self.folderUnavailableMessage
        default: return nil
        }
    }

    private func select(_ method: PreferencesStore.SyncMethod) {
        guard method == .folder else {
            preferencesStore.setSyncMethod(method)
            return
        }
        showingFolderDisclosure = true
    }

    private func chooseFolder() {
        selectionError = nil
        isChoosingFolder = true
        defer { isChoosingFolder = false }
        guard let url = configurationFolderClient.chooseDirectory() else { return }
        let client = configurationFolderClient.makeClient(for: url)
        switch client.read() {
        case .missing:
            guard client.write(preferencesStore.browserSettingsSnapshot()) else {
                selectionError = "The shared settings file could not be written."
                return
            }
        case let .snapshot(snapshot, bytes):
            if snapshot == preferencesStore.browserSettingsSnapshot() {
                if !preferencesStore.configureFolderSync(client: client, displayName: url.lastPathComponent) {
                    selectionError = "Folder access is unavailable. Choose the folder again to recover."
                }
            } else {
                pendingFolderClient = client
                pendingFolderSnapshot = snapshot
                pendingFolderBytes = bytes
                showingFolderAdoption = true
            }
            return
        case .unavailable:
            selectionError = "Folder access is unavailable. Choose the folder again to recover."
            return
        case .invalid:
            selectionError = "The shared settings file is invalid and was left untouched."
            return
        }
        guard preferencesStore.configureFolderSync(client: client, displayName: url.lastPathComponent) else {
            selectionError = "Folder access is unavailable. Choose the folder again to recover."
            return
        }
    }
}

private struct DefaultBrowserSettingsRow: View {
    let client: DefaultBrowserClient

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconStyle)
                .font(.title3)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.settingsDefaultBrowserStatus
                    )

                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if client.status == .current {
                Label("Active", systemImage: "checkmark")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(
                        AccessibilityIdentifier.settingsDefaultBrowserActive
                    )
            } else {
                Button {
                    Task {
                        await client.requestDefaultBrowser()
                    }
                } label: {
                    if client.isRequesting {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Making Default…")
                        }
                    } else {
                        Text("Make Default")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(client.isRequesting)
                .accessibilityIdentifier(
                    AccessibilityIdentifier.settingsDefaultBrowserAction
                )
            }
        }
    }

    private var title: String {
        switch client.status {
        case .current:
            "Katabro is the default browser"
        case .notCurrent:
            "Katabro is not the default browser"
        case .unavailable:
            "Default browser status unavailable"
        }
    }

    private var detail: String {
        switch client.status {
        case .current:
            "Web links are routed through Katabro."
        case .notCurrent:
            "Make Katabro the default to route web links."
        case .unavailable:
            "Try again by making Katabro the default browser."
        }
    }

    private var iconName: String {
        client.status == .current
            ? "checkmark.circle.fill"
            : "exclamationmark.triangle.fill"
    }

    private var iconStyle: Color {
        client.status == .current
            ? .green
            : .orange
    }
}

private extension FilePreferencesClient.ReadResult {
    var snapshotValue: BrowserSettingsSnapshot? {
        guard case let .snapshot(snapshot, _) = self else { return nil }
        return snapshot
    }
}
