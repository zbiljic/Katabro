# Katabro

Katabro is a macOS menu bar utility that asks which browser should open each web
link. It discovers registered browsers through Launch Services, presents a
keyboard-friendly picker near the pointer, and remembers the preferred browser
order.

Katabro currently targets macOS 14 or newer. Linux and Windows support, signed
release artifacts, notarization, and an installer are not available yet.

## Features

- Handles HTTP and HTTPS links after macOS confirms Katabro as the default
  browser.
- Discovers compatible browsers without a hard-coded browser list.
- Supports arrow keys, Return or Space, Escape, numeric picker shortcuts, and
  optional per-browser letter shortcuts.
- Queues simultaneous link requests instead of dropping them.
- Provides onboarding, Settings, open-at-login control, browser ordering, and
  shortcut assignment under **Shown Browsers**.
- Syncs browser order and picker shortcuts through iCloud across Macs using the
  same Apple Account.
- Bundles a `katabro` command-line helper inside the application.
- Keeps URL validation and routing policy in a portable Swift package.

## Build and run from source

Requirements:

- macOS 14 or newer
- Xcode 26.4 or newer with Swift 6.3
- [mise](https://mise.jdx.dev/)

Clone the repository, then run:

```sh
mise install
mise run check
scripts/run
```

The build is created at
`Derived/Build/Products/Debug/Katabro.app`. Katabro is an agent application, so
it appears in the menu bar rather than the Dock. Stop the development build
with:

```sh
scripts/stop
```

## Set up Katabro

1. Open the Katabro menu bar item and choose **Finish Setup…**.
2. Choose **Use Katabro as Default Browser…**.
3. Confirm the HTTP and HTTPS handler changes requested by macOS.
4. Check the status shown by Katabro. It reports success only after Launch
   Services identifies Katabro as the handler for both schemes.

The default browser, login item, and browser order can be revisited in Settings
with Command-Comma.

## Command-line helper

The application bundle contains the helper at:

```text
Katabro.app/Contents/Helpers/katabro
```

For a development build, the wrapper script locates that helper and forwards
its arguments:

```sh
scripts/katabro 'https://example.com/path?q=swift'
```

The helper accepts exactly one absolute HTTP or HTTPS URL. It validates the URL,
encodes it as a `katabro://open` request, and asks macOS to deliver it to the
application. Invalid input and launch failures return a nonzero exit status.

## Development commands

```sh
mise tasks              # list all tasks
mise run generate       # generate the Xcode workspace without opening Xcode
mise run build          # build the portable package and macOS app
mise run test           # run core and app tests
mise run fmt            # format Swift and manifest files
mise run lint           # run SwiftLint in strict mode
mise run check          # run the complete local validation gate
mise run clean          # remove generated projects and build outputs
```

Tuist is the source of truth for the Xcode project. Do not commit generated
`.xcodeproj` or `.xcworkspace` files.

Browser-order sync requires a correctly entitled build signed for an App ID
with iCloud key-value storage enabled, such as a provisioned development or App
Store build. Source builds without that capability keep browser preferences
locally and continue to work without iCloud.

Custom picker letters sync through iCloud in entitled builds. Assign one letter
from A through Z to a browser in Settings > Browsers. Assigning a letter already
in use moves it to the new browser. Numeric shortcuts 1 through 9 remain active
at the same time and always follow the visible picker order.

The default `Katabro` scheme deliberately has no iCloud entitlement and is the
scheme used by `mise run check` and `scripts/run`. Apple Developer Program team
members can build the separate provisioned scheme after selecting a development
team for `com.zbiljic.katabro`:

```sh
mise run app:build:icloud
```

The `Katabro iCloud` scheme is the only scheme that instantiates the live iCloud
key-value store. Both schemes compile the same synchronization implementation,
and the default scheme exercises it through deterministic in-memory tests.

## Review the interface

Debug builds can open deterministic review windows without reading or changing
the real default-browser, login-item, or Launch Services state:

```sh
scripts/run settings normal
scripts/run settings service-errors
scripts/run settings many-browsers light
scripts/run onboarding normal
scripts/run picker normal dark
scripts/run menu normal
```

Available fixture states are `normal`, `loading`, `no-browsers`,
`browser-discovery-error`, `service-errors`, and `many-browsers`. The optional
appearance is `system`, `light`, or `dark`. Normal `scripts/run` behavior remains
menu-bar only.

The `KatabroUITests` target exercises these surfaces and keeps screenshots as
test-result attachments:

```sh
tuist xcodebuild test \
  -scheme Katabro \
  -configuration Debug \
  -derivedDataPath Derived \
  -only-testing:KatabroUITests
```

## Project documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## License

Katabro is available under the terms in [LICENSE](LICENSE).
