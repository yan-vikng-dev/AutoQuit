# Releasing AutoQuit

AutoQuit is distributed outside the Mac App Store as a Developer ID signed and
notarized macOS app, published as GitHub Releases and via a Homebrew tap.

## Commit message convention

Release notes are auto-generated from `git log` by `git-cliff`, so commit
messages drive what users see on the GitHub release page. Use
[Conventional Commits](https://www.conventionalcommits.org/) prefixes:

| Prefix      | Goes into release notes section | Use for                              |
|-------------|---------------------------------|--------------------------------------|
| `feat:`     | Features                        | New user-facing capability           |
| `fix:`      | Bug fixes                       | Bug fix                              |
| `perf:`     | Performance                     | Speed/memory improvement             |
| `refactor:` | Refactor                        | Code reshape without behavior change |
| `docs:`     | Documentation                   | README/inline docs                   |
| `test:`     | Tests                           | Test-only change                     |
| `build:`    | Build                           | Build system / scripts               |
| `ci:`       | CI                              | CI-only change                       |
| `chore:`    | _(omitted from notes)_          | Routine maintenance, dep bumps       |

Append `!` after the prefix for a breaking change: `feat!: drop macOS 12`.
The resulting line in the notes will be flagged as `(**breaking**)`.

Commits without a prefix still appear, bucketed under "Other". Try to avoid
that — they read as "miscellaneous" on the release page.

Preview release notes for the next version any time with:

```bash
git-cliff --tag v1.0.2 --unreleased
```

## Cutting a release

The single source of truth for the version is the `<version>` argument you pass
to `just release`. The script does everything else.

```bash
just release 1.0.2
```

This will:

- Pre-flight: refuse to release if the working tree is dirty, you're not on
  `main`, `main` is out of sync with `origin/main`, the tag already exists
  locally or remotely, the GitHub release already exists, or there are no
  commits since the last tag.
- Build `AutoQuit.app` as a Universal binary (arm64 + x86_64) with the new
  `MARKETING_VERSION` and an auto-incremented `CURRENT_PROJECT_VERSION`.
- Sign with the installed `Developer ID Application` identity.
- Build a signed DMG, notarize it with Apple, staple the ticket, and verify
  with `codesign`, `stapler`, and `spctl`.
- Write the bumped `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` back into
  `project.yml`, commit, tag (`vX.Y.Z`, annotated), and push to `origin main`.
- Generate release notes from the commit messages between the previous tag
  and `HEAD` via `git-cliff` (config in `cliff.toml`).
- Publish a GitHub release for the tag with the `.dmg` and its `.sha256`
  attached, using the generated notes as the body.

Artifacts land in `dist/AutoQuit-v<version>.dmg` and `…dmg.sha256`.

### Versioning

Marketing version follows SemVer (`MAJOR.MINOR.PATCH`). The build number
(`CURRENT_PROJECT_VERSION`) is auto-incremented on every release and is what
Sparkle and the App Store use to detect "is this newer?". Never decrement or
reuse a build number.

### Useful overrides

```bash
SKIP_PUSH=1 just release 1.0.2              # build + tag locally, don't push
SKIP_GITHUB_RELEASE=1 just release 1.0.2    # everything except gh release create
NOTARYTOOL_PROFILE=my-profile just release 1.0.2
DEVELOPER_ID_APPLICATION="Developer ID Application: Example Name (TEAMID)" \
  just release 1.0.2
```

## Homebrew tap update

After a GitHub release is published, update the cask in
`yan-vikng-dev/homebrew-tap` so `brew install --cask autoquit` picks up the
new version:

```bash
just release-homebrew 1.0.2
```

This is `just release` + a `brew bump-cask-pr` step on top. If the GitHub
release is already published (e.g. because `just release` succeeded but the
cask bump failed), skip the rebuild:

```bash
SKIP_BUILD=1 just release-homebrew 1.0.2
```

Or just bump the cask directly without going through the release script:

```bash
just homebrew-cask 1.0.2
```

The cask bump:

- Verifies the local tap working tree is clean and on `main`.
- Pulls the latest `main`.
- Runs `brew bump-cask-pr --version <version> --sha256 <dmg-sha256>` against
  the tap, which opens a PR with the updated `version` and `sha256` fields.

Useful overrides:

```bash
HOMEBREW_CASK_DRY_RUN=1 just homebrew-cask 1.0.2
HOMEBREW_CASK_WRITE_ONLY=1 just homebrew-cask 1.0.2
HOMEBREW_TAP_NAME=yan-vikng-dev/tap just homebrew-cask 1.0.2
```

End-user install commands:

```bash
brew tap yan-vikng-dev/tap
brew install --cask autoquit
```

## Recovering from a failed release

The release script is structured so the *destructive* git steps (commit, tag,
push, publish) only run after a successful build + notarization. So if the
build fails partway through, `project.yml` is untouched and no commits or tags
were created — fix the issue and re-run.

If the script fails *after* the commit/tag/push but before
`gh release create`, you'll have a tag pushed to origin without a GitHub
release. To recover, re-run with `SKIP_PUSH=1` and a fresh patch version, or
manually:

```bash
gh release create v1.0.2 dist/AutoQuit-v1.0.2.dmg dist/AutoQuit-v1.0.2.dmg.sha256 \
  --repo yan-vikng-dev/AutoQuit \
  --title "AutoQuit v1.0.2" \
  --generate-notes
```
