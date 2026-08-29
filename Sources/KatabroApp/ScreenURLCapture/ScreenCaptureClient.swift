import AppKit
@preconcurrency import CoreGraphics
@preconcurrency import ScreenCaptureKit

enum ScreenCaptureAuthorization: Equatable, Sendable {
    case authorized
    case notAuthorized
}

enum ScreenCaptureClientError: Error, Sendable {
    case unavailableDisplay
    case captureFailed
}

@MainActor
struct ScreenCaptureClient {
    let authorizationStatus: () -> ScreenCaptureAuthorization
    let requestAuthorization: () -> Bool
    let capture: () async throws -> CGImage
    var openSystemSettings: () -> Void = {}

    static let live = Self(
        authorizationStatus: {
            CGPreflightScreenCaptureAccess() ? .authorized : .notAuthorized
        },
        requestAuthorization: {
            CGRequestScreenCaptureAccess()
        },
        capture: {
            do {
                guard CGPreflightScreenCaptureAccess() else {
                    throw ScreenCaptureClientError.captureFailed
                }
                let content = try await SCShareableContent.current
                let pointer = NSEvent.mouseLocation
                let pointerScreen = NSScreen.screens.first { $0.frame.contains(pointer) }
                let pointerDisplayID = displayID(for: pointerScreen)
                let mainDisplayID = displayID(for: NSScreen.main)
                guard
                    let display = content.displays.first(where: { $0.displayID == pointerDisplayID })
                    ?? content.displays.first(where: { $0.displayID == mainDisplayID })
                else { throw ScreenCaptureClientError.unavailableDisplay }
                let ownApplication = content.applications.first {
                    $0.bundleIdentifier == Bundle.main.bundleIdentifier
                }
                let filter = SCContentFilter(
                    display: display,
                    excludingApplications: ownApplication.map { [$0] } ?? [],
                    exceptingWindows: []
                )
                let configuration = SCStreamConfiguration()
                configuration.showsCursor = false
                configuration.capturesAudio = false
                let size = ScreenCaptureImageSize.size(
                    width: filter.contentRect.width * CGFloat(filter.pointPixelScale),
                    height: filter.contentRect.height * CGFloat(filter.pointPixelScale)
                )
                configuration.width = size.width
                configuration.height = size.height
                return try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: configuration
                )
            } catch let error as ScreenCaptureClientError {
                throw error
            } catch {
                throw ScreenCaptureClientError.captureFailed
            }
        },
        openSystemSettings: {
            openScreenRecordingSettings()
        }
    )

    private static func openScreenRecordingSettings() {
        let legacy = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        let current = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
        let candidates = if #available(macOS 26, *) {
            [current, legacy]
        } else {
            [legacy, current]
        }
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private static func displayID(for screen: NSScreen?) -> CGDirectDisplayID? {
        screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    static let inert = Self(
        authorizationStatus: { .notAuthorized },
        requestAuthorization: { false },
        capture: { throw ScreenCaptureClientError.captureFailed }
    )
}

struct ScreenCaptureImageSize: Equatable, Sendable {
    let width: Int
    let height: Int

    static func size(width: CGFloat, height: CGFloat) -> Self {
        guard width > 0, height > 0 else { return Self(width: 1, height: 1) }
        let scale = min(1, 5120 / max(width, height))
        return Self(width: max(1, Int((width * scale).rounded())), height: max(1, Int((height * scale).rounded())))
    }
}
