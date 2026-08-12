import AppKit
import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(
                        nsImage: NSApplication.shared.applicationIconImage
                    )
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: 96,
                        height: 96
                    )
                    .accessibilityHidden(true)

                    Text(AppMetadata.displayName)
                        .font(.title)

                    Text("Version \(AppMetadata.versionDescription)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(
                            AccessibilityIdentifier.settingsAboutVersion
                        )
                }

                VStack(spacing: 8) {
                    Text("Choose which browser opens each link.")
                        .font(.body)
                    Text("Links are routed locally on this Mac.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                ViewThatFits {
                    HStack(spacing: 20) {
                        aboutLinks
                    }

                    VStack(spacing: 8) {
                        aboutLinks
                    }
                }

                Text(AppMetadata.copyright)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .accessibilityIdentifier(
            AccessibilityIdentifier.settingsAboutContent
        )
    }

    @ViewBuilder private var aboutLinks: some View {
        Link(destination: AppMetadata.repositoryURL) {
            Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        .accessibilityIdentifier(
            AccessibilityIdentifier.settingsAboutRepositoryLink
        )

        Link(destination: AppMetadata.issuesURL) {
            Label("Report an Issue", systemImage: "exclamationmark.bubble")
        }
        .accessibilityIdentifier(
            AccessibilityIdentifier.settingsAboutIssuesLink
        )

        Link(destination: AppMetadata.licenseURL) {
            Label("MIT License", systemImage: "doc.text")
        }
        .accessibilityIdentifier(
            AccessibilityIdentifier.settingsAboutLicenseLink
        )
    }
}
