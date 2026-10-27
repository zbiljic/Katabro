# Releasing Katabro

Set the version and build number in `Resources/Info.plist`, then run
`mise run check:ci` and `mise run package`. This creates
`dist/Katabro-VERSION-arm64.zip` and its SHA-256 checksum for the GitHub
release tagged `vVERSION`. The ZIP includes the app and its bundled CLI for
Apple silicon Macs running macOS 14 or later; Intel Macs are not supported.

Commit and push the release changes, then run the manual
[UI Tests workflow](.github/workflows/ui-tests.yml) for that branch. Confirm that
both **CI** and **UI Tests** pass for the release commit before tagging it.
The UI suite has a 60-minute limit and runs separately from routine CI.

Tag the tested commit with the app version (for example, `0.2.0`):

```sh
git tag v0.2.0
git push origin v0.2.0
```

The [release workflow](.github/workflows/release.yml) checks the tag against
`Resources/Info.plist`, runs `mise run package`, and creates a draft release
with the ZIP, checksum, and a static installation description. It uses ad hoc
signing; no Apple Developer ID or signing secrets are needed. Review the draft
and the CI and UI Tests results for the tagged commit, then click **Publish
release** on GitHub.

After publishing, update `version` and `sha256` in
`Casks/katabro.rb` in [the Homebrew tap](https://github.com/zbiljic/homebrew-tap)
using the checksum attached to that release, then commit and push the cask.

## Release notes

The release description can be edited before or after publishing, on GitHub
or with the local task below. CI does not generate a change summary.

Write the complete release description in `dist/release-notes-v0.2.0.md`,
then update the existing release:

```sh
mise run release-notes v0.2.0 dist/release-notes-v0.2.0.md
```

This requires an authenticated `gh` CLI and replaces the full description,
so keep the installation and signing information in the file. It leaves
assets and the draft/published status unchanged.
