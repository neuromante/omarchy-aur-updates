# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.1.0]: https://github.com/neuromante/omarchy-aur-updates/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/neuromante/omarchy-aur-updates/releases/tag/v1.0.0
