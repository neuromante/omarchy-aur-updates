# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] - 2026-09-26

### Fixed

- Treat malformed `yay` output and failed queries as errors instead of
  displaying error text as a package or silently reporting no updates.
- Retry failed changelog lookups after five minutes rather than keeping them
  cached for six hours.
- Bound the complete changelog lookup to 30 seconds and avoid an AUR RPC call
  when all requested package results are cached.

### Changed

- Document changelog support for GitHub and GitLab upstreams.
- Quote the configured update command through both shell invocations so its
  quotes and variable references are interpreted in the floating terminal.

### Added

- Add unit tests for yay output parsing, changelog cache expiry and lookup
  timeouts.

## [1.2.0] - 2026-09-26

### Added

- Each updatable package can now show a short upstream changelog under its row:
  up to two lines of the most recent commit subjects, expandable to the full
  list on click.
- New `bin/aur-changelog` helper: resolves the upstream URL from the AUR RPC
  and fetches recent commits (merge commits skipped) from GitHub or GitLab,
  with a six-hour cache.

### Notes

- The per-package changelog is available for upstreams published on GitHub or
  GitLab.

## [1.1.2] - 2026-09-25

### Changed

- The update button now re-checks as soon as the update command exits, so a
  successful update clears the pending-count badge immediately instead of
  waiting for the next hourly poll. A partial or failed update refreshes the
  remaining list right away.

## [1.1.1] - 2026-09-25

### Changed

- Removed the redundant refresh icon in the popup header; the bottom
  "Controlla adesso" button is now the single way to trigger a check.
- Slightly shrunk the pending-updates count badge on the bar icon.

## [1.1.0] - 2026-09-25

### Added

- Package names in the popup are now hyperlinks to their
  `aur.archlinux.org/packages/<name>` page. Clicking one opens the default
  browser, with a detached `xdg-open` fallback when the Qt desktop service
  cannot be reached.
- Hover tooltip on a package name showing its AUR URL.

## [1.0.0] - 2026-09-25

### Added

- Initial release.
- Arch-logo bar widget with a live count badge when updates are available.
- Automatic AUR update check every hour (configurable via `intervalHours`),
  backed by `yay -Qua` with a timeout guard.
- Detail popup listing each upgradable package as `installed → latest`.
- "Update with yay" button running the configurable `updateCommand` in a
  floating terminal.

[Unreleased]: https://github.com/neuromante/omarchy-aur-updates/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/neuromante/omarchy-aur-updates/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/neuromante/omarchy-aur-updates/compare/v1.1.2...v1.2.0
[1.1.2]: https://github.com/neuromante/omarchy-aur-updates/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/neuromante/omarchy-aur-updates/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/neuromante/omarchy-aur-updates/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/neuromante/omarchy-aur-updates/releases/tag/v1.0.0
