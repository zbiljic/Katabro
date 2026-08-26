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
- Routes local HTML and XHTML documents to a selected browser without treating
  file URLs as default-browser schemes.
- Discovers compatible browsers without a hard-coded browser list.
- Supports arrow keys, Return or Space, Escape, numeric picker shortcuts, and
  optional per-browser letter shortcuts.
- Configures compact vertical or horizontal picker layout, visible choices,
  destination and shortcut detail, and the Remember option in **Settings > Picker**.
- Opens private windows and profiles for supported Chromium- and Firefox-family
  browsers while retaining the App Sandbox, after user-authorized setup.
- Queues simultaneous link requests instead of dropping them.
- Can remember a browser choice for one exact host and remove that local rule
  later in **Settings > Rules**.
- Shows up to three recent host-only routing decisions in **Settings > Rules**,
  with an in-memory Show All view and rule creation from successful routes.
- Provides onboarding, Settings, open-at-login control, browser ordering, and
  shortcut assignment under **Shown Browsers**.
- Syncs browser order and picker shortcuts through iCloud, or those settings
  plus exact-host rules through a user-selected folder.
- Bundles a `katabro` command-line helper inside the application.
- Keeps URL validation and routing policy in a portable Swift package.
- Opens absolute HTTP, HTTPS, and local file URLs from the clipboard only when
  requested, without monitoring clipboard history. Clipboard managers such as
  Maccy require no special integration.
- Copies the pending web or local-file link with Command-C or the destination's
  **Copy Link** context-menu action.

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

### Exact-host rules

In the browser picker, select **Remember this choice for &lt;host&gt;** before
opening a link to remember that exact host. Press Shift-Command-R to toggle the
option from the keyboard. For example, a rule for
`example.com` does not apply to `www.example.com` or another subdomain. Katabro
stores only the normalized host and the selected launch-target identifier—not
the full URL, path, query, or browsing history. These rules remain on this Mac
and are not included in iCloud synchronization.

Open **Settings > Rules** to review a rule, remove one rule, or remove them all.
If its browser, private-window helper, or profile is unavailable, Katabro keeps
the rule and shows the picker instead.

The same pane shows the three newest **Recent Routes** for the current Katabro
session. Expand the section to review all retained entries or create and replace
exact-host rules from successful routes. Recent Routes stores hostnames only,
keeps at most 50 entries in memory, and clears on Clear or when Katabro quits.

### Settings sync

Open **Settings > General > Sync** to keep settings on this Mac, sync through
iCloud, or use a folder managed by a provider of your choice.

| Setting | This Mac | iCloud | Folder |
| --- | --- | --- | --- |
| Browser order | local | sync | sync |
| Picker shortcuts | local | sync | sync |
| Exact-host rules | local | local only | sync after disclosure |
| Hidden browsers, onboarding, profiles, helper state | local | local | local |

Folder sync writes `katabro-settings.json` to the selected folder. Choose the
same folder separately on each Mac. An empty folder is initialized from the
current Mac; when a valid file already exists, Katabro offers to use it or
replace it with this Mac's settings.

Exact-host rules contain normalized hostnames and opaque target identifiers, so
Katabro asks for confirmation before enabling Folder sync. Folder access and
its security-scoped bookmark remain local to each Mac.

The shared file uses this version 1 JSON format:

```json
{
  "version": 1,
  "order": ["com.apple.Safari"],
  "shortcuts": {"com.apple.safari": "S"},
  "routingRules": [{
    "matchHost": "example.com",
    "targetIdentifier": "com.apple.safari"
  }]
}
```

Folder sync uses snapshot-level last-writer-wins. Invalid, unsupported, or
unavailable files are left untouched and local settings continue to work. If a
folder moves or its permissions change, choose it again. Disconnecting selects
**This Mac** without deleting the shared file or local rules.

Target identifiers are treated as opaque. If a browser or profile is unavailable
on another Mac, Katabro keeps its rule and opens the browser picker instead.

### Browser profiles and private windows

Open **Settings > Browsers** and use **Profiles & Private Windows**:

1. Choose **Set Up…** to open the launcher-helper guide.
2. Choose **Install open.sh…**.
3. Confirm the preselected `open.sh` location in the system Save Panel. Katabro
   installs its bundled helper and updates the status automatically.
4. To add named profiles, choose **Choose Folder…** for each supported browser
   and select the browser data folder shown in Settings.

Katabro compares the installed helper byte for byte with its bundled version.
An executable helper with different contents remains usable and is shown as a
custom or older helper; Katabro offers to replace it but never overwrites it
automatically. Private-window entries need only the helper; named profiles also
need access to the corresponding browser data folder.

Katabro remains sandboxed. The user-installed script runs `/usr/bin/open` with
structured arguments outside the sandbox. Security-scoped bookmarks let Katabro
read profile metadata from folders selected by the user. The Save Panel flow
requires the sandbox's user-selected read/write entitlement, but Katabro does
not modify browser profile folders. Folder permissions stay local to this Mac
and are not synced through iCloud. Safari profiles are not supported.

The Application Scripts folder must be named exactly
`~/Library/Application Scripts/com.zbiljic.katabro` because its name must match
Katabro's bundle identifier, including capitalization.

## Command-line helper

The application bundle contains the helper at:

```text
Katabro.app/Contents/Helpers/katabro
```

For a development build, the wrapper script locates that helper and forwards
its arguments:

```sh
scripts/katabro 'https://example.com/path?q=swift'
scripts/katabro 'file:///tmp/example%20page.html'
```

The helper accepts exactly one absolute HTTP, HTTPS, or local file URL. It validates the URL,
encodes it as a `katabro://open` request, and asks macOS to deliver it to the
application. Invalid input and launch failures return a nonzero exit status.

macOS document delivery is registered only for HTML and XHTML documents.
HTTP and HTTPS remain the only default-browser schemes; Katabro does not claim
generic files or use file associations for default-browser status.

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
scripts/run picker browser-profiles dark
scripts/run settings script-setup light
scripts/run settings script-replace dark
scripts/run settings recent-routes light
scripts/run settings recent-routes dark
scripts/run settings recent-routes-empty light
scripts/run menu normal
```

Available fixture states are `normal`, `loading`, `no-browsers`,
`browser-discovery-error`, `service-errors`, `many-browsers`,
`browser-profiles`, `script-setup`, `script-replace`, `recent-routes`, and
`recent-routes-empty`. The optional
appearance is `system`, `light`, or `dark`.
Normal `scripts/run` behavior remains menu-bar only.

The `KatabroUITests` target exercises these surfaces and keeps screenshots as
test-result attachments:

```sh
tuist xcodebuild test \
  -scheme Katabro \
  -configuration Debug \
  -derivedDataPath Derived \
  -only-testing:KatabroUITests
```

## License

Katabro is available under the terms in [LICENSE](LICENSE).
