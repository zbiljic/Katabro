# Katabro

Katabro is a macOS menu bar app that lets you choose which browser opens each
web link. It discovers installed browsers through Launch Services, presents a
keyboard-friendly picker, and remembers your preferred browser order.

Katabro requires macOS 14 or later.

## Highlights

- Opens HTTP, HTTPS, and local HTML or XHTML links in the browser you choose.
- Discovers registered browsers automatically, without a hard-coded browser
  list.
- Supports keyboard navigation, numeric shortcuts, and optional letter
  shortcuts.
- Routes exact hosts automatically with local rules and falls back to the
  picker when a saved browser or profile is unavailable.
- Opens private windows and named profiles in supported Chromium- and
  Firefox-family browsers after user-authorized setup.
- Provides optional global shortcuts for the menu, clipboard URLs, and on-device
  screen URL recognition.
- Syncs settings through iCloud or a folder you choose.
- Queues simultaneous requests instead of dropping them.
- Remains sandboxed and keeps routing history, profile access, shortcuts, and
  system-facing preferences under the user's control.
- Includes a `katabro` command-line helper in the application bundle.

## Installation

Prebuilt [releases](https://github.com/zbiljic/Katabro/releases) are being
prepared. Once published, install the app and bundled CLI with:

```sh
brew install --cask zbiljic/tap/katabro
```

For manual installation, download the release ZIP, unzip it, and move
`Katabro.app` to `/Applications`.

Initial releases are ad hoc signed and not notarized. If macOS blocks opening
Katabro, go to **System Settings → Privacy & Security → Open Anyway**, then
confirm **Open**. See [Apple's guide](https://support.apple.com/en-us/102445).

Alternatively, if you trust the downloaded release, remove its quarantine
attribute in Terminal, then open Katabro again:

```sh
xattr -dr com.apple.quarantine /Applications/Katabro.app
```

Local and folder sync work; iCloud sync requires a separate provisioned build.

## Build and run

Requirements:

- macOS 14 or later
- Xcode 26.4 or later with Swift 6.3
- [mise](https://mise.jdx.dev/)

Clone the repository and launch a development build:

```sh
git clone https://github.com/zbiljic/Katabro.git
cd Katabro
mise install
scripts/run
```

The app is built at `Derived/Build/Products/Debug/Katabro.app`. Katabro is a
menu bar app, so it does not appear in the Dock. Stop the development build
with:

```sh
scripts/stop
```

## First-time setup

1. Open Katabro from the menu bar and choose **Finish Setup…**.
2. On **Set Up Katabro**, choose **Use Katabro as Default Browser…** and
   confirm the HTTP and HTTPS handler changes requested by macOS. You can still
   continue if the system request needs attention later.
3. Choose **Continue** after reviewing the live default-browser status.
4. On **Open Copied Links Faster**, optionally enable the proposed
   Control-Command-B shortcut. The shortcut is off by default and stays on this
   Mac.
5. Choose **Done** to finish setup.

Existing users can reopen both steps from **More > Setup Guide…** without
changing their completed setup state.

Open Settings (`⌘,`) to change the default-browser status, login item, browser
order, picker layout, shortcuts, rules, and sync options.

## Optional features

### Exact-host rules

Enable **Remember this choice for &lt;host&gt;** in the browser picker before opening
a link, or press Shift-Command-R. Rules match only that normalized host: a rule
for `example.com` does not match `www.example.com` or another subdomain.

Katabro stores the host and selected target identifier, not the full URL, path,
query, or browsing history. Review or remove rules in `Settings → Rules`.
Recent routes contain hostnames only, remain in memory, and are cleared when
Katabro quits.

### Global shortcuts and URL capture

- **Menu:** Enable the optional Option-Command-K shortcut in
  `Settings → General → Menu Bar` to show or hide Katabro's menu from any app.
- **Clipboard URL:** Choose **Open URL from Clipboard** from the menu, or enable
  the optional Control-Command-B shortcut in
  `Settings → General → Clipboard URL`. Katabro reads the clipboard only when
  requested and does not keep clipboard history.
- **Screen URL capture:** Choose **Capture URLs from Screen** to capture the
  display under the pointer and recognize web URLs locally with Apple Vision.
  The optional shortcut is Control-Command-X and is configured in
  `Settings → General → Screen URL Capture`.

All three shortcuts are device-local and off by default. Clipboard and menu
shortcuts require neither Accessibility nor Input Monitoring access. Screen URL
capture requests Screen Recording access only for that feature; screenshots,
recognized text, and detected URLs remain in memory and are not saved, synced,
or sent to a service.

### Settings sync

Choose a sync mode in `Settings → General → Sync`:

| Setting | This Mac | iCloud | Folder |
| --- | --- | --- | --- |
| Browser order | Local | Synced | Synced |
| Picker shortcuts | Local | Synced | Synced |
| Exact-host rules | Local | Local | Synced after confirmation |
| Other app and system settings | Local | Local | Local |

Folder sync writes `katabro-settings.json` to a folder selected separately on
each Mac. Because exact-host rules contain hostnames and target identifiers,
Katabro asks for confirmation before enabling Folder sync. If a synced browser
or profile is unavailable on another Mac, the rule is kept and the picker opens
instead.

To test iCloud sync, use a provisioned App ID and build the `Katabro iCloud`
scheme:

```sh
mise run app:build:icloud
```

### Browser profiles and private windows

Open `Settings → Browsers → Profiles & Private Windows` to install Katabro's
bundled `open.sh` helper and authorize browser profile folders. Private-window
targets need only the helper; named profiles also need access to the selected
browser data folder.

Katabro remains sandboxed. The helper delegates structured arguments to
`/usr/bin/open`, and security-scoped bookmarks limit profile access to folders
selected by the user. Profile folders and bookmarks stay on this Mac. Safari
profiles are not supported.

## Command-line helper

The application bundle contains the helper at:

```text
Katabro.app/Contents/Helpers/katabro
```

The CLI requires the app and is included in the release ZIP. Homebrew puts
`katabro` on `PATH`.

For a development build, use the wrapper script:

```sh
scripts/katabro 'https://example.com/path?q=swift'
scripts/katabro 'file:///tmp/example%20page.html'
```

The helper accepts one absolute HTTP, HTTPS, or local file URL, validates it,
and asks macOS to deliver it to Katabro. Invalid input and launch failures
return a nonzero exit status.

## Development

Common commands:

```sh
mise tasks              # list all tasks
mise run generate       # generate the Xcode workspace
mise run build          # build the core package and app
mise run test           # run core and app tests
mise run fmt            # format Swift and manifest files
mise run lint           # run SwiftLint in strict mode
mise run check          # run the complete validation gate
mise run package        # package the app and bundled CLI
mise run clean          # remove generated projects and build outputs
```

`Project.swift` and `Tuist.swift` are the source of truth. Do not commit the
generated `.xcodeproj` or `.xcworkspace` files.

Debug builds also provide deterministic UI-review surfaces that do not modify
the real default-browser, login-item, or Launch Services state:

```sh
scripts/run settings normal
scripts/run onboarding normal
scripts/run picker many-browsers dark
scripts/run menu normal
scripts/run --help
```

## Packaging

See [RELEASING.md](RELEASING.md) for packaging and publishing releases.

## License

Katabro is licensed under the [MIT License](LICENSE).
