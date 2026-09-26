# Omarchy AUR Updates

An [Omarchy](https://omarchy.org/) shell bar widget that keeps an eye on the
AUR packages installed on your machine and tells you when they can be updated.

The bar shows the Arch logo; when upgrades are available it turns urgent and a
small badge with the count appears. Clicking it opens a popup that lists every
upgradable package together with the installed and the latest version, plus a
button to run the update.

## Features

- Arch logo in the bar, with a count badge when updates are available.
- Automatic background check every hour (configurable).
- Popup listing each upgradable package as `installed → latest`.
- Package names are hyperlinks to their AUR page: clicking one opens it in your
  default browser.
- "Update with yay" button that runs the configured command in a floating
  terminal.
- Hover tooltip summarising the pending updates.
- Timeout-safe: a slow or unresponsive AUR query never blocks the shell.

## Requirements

- Omarchy (the Quickshell-based shell), with `omarchy plugin` available.
- [`yay`](https://github.com/Jguer/yay) for the AUR queries and updates.
- `python3` for the helper script (`bin/aur-updates`).

## Installation

Install it straight from the Omarchy plugin manager:

```bash
omarchy plugin add https://github.com/neuromante/omarchy-aur-updates --enable --yes
```

It lands in the right-hand bar section by default. Move it anywhere with:

```bash
omarchy bar move neuromante.aur-updates --section right
```

For a manual install, drop this repository into
`~/.config/omarchy/plugins/neuromante.aur-updates/`, then run:

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable neuromante.aur-updates
```

## Usage

- **Left click** the Arch icon: open or close the detail popup.
- **Middle click**: force an immediate check.
- Inside the popup: `r` re-checks, `Esc` closes, arrow keys scroll the list.
- **Click a package name** in the popup: open its `aur.archlinux.org` page in
  the default browser.
- The button launches the configured update command in a floating terminal;
  when it exits, the widget re-checks automatically, so a successful update
  clears the badge right away.

## Settings

Settings live inline on the widget's entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "neuromante.aur-updates",
  "intervalHours": 1,
  "updateCommand": "yay -Sua"
}
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `intervalHours` | integer (1–24) | `1` | How often to check for AUR updates. |
| `updateCommand` | string | `yay -Sua` | Command run by the button, inside a floating terminal. |

## About the update command

The check uses `yay -Qua`, which compares the installed foreign (AUR) packages
against the AUR RPC and needs neither root nor a refreshed sync database.

The default button command is `yay -Sua`, the standard "sync, sysupgrade,
AUR only" invocation. Note that `yay --aur` on its own is **not** an update
command — it just restricts yay to AUR and, with no operation, prints yay's
help. If you use a wrapper or alias, point the widget at it with
`updateCommand`.

## How it works

`bin/aur-updates` runs `yay -Qua --color never`, parses each
`<name> <installed> -> <latest>` line, and prints a single JSON object:

```json
{
  "count": 1,
  "packages": [
    { "name": "faugus-launcher", "current": "2.4.1-1", "latest": "2.5.0-1" }
  ],
  "error": "",
  "checked": 1790340235
}
```

`BarWidget.qml` schedules the script, keeps the latest result, and forwards it
to `Panel.qml`, which only handles presentation. The QML side never parses yay
output itself.

## Repository layout

```
manifest.json     Plugin manifest (id, entry points, settings schema)
BarWidget.qml     Bar icon, badge, polling, panel wiring
Panel.qml         Detail popup (package list + update button)
bin/aur-updates   yay query wrapper -> JSON
CHANGELOG.md      Release history
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
