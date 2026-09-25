import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// AUR update notifier.
//
//   idle:            " (Arch glyph)"        (plain)
//   updates found:   glyph in urgent color + a small count badge
//
// Left click opens the detail popup, middle click forces an immediate check.
// The heavy lifting lives in bin/aur-updates; this file only schedules it,
// stores the result, and forwards it to Panel.qml.

BarWidget {
  id: root
  moduleName: "neuromante.aur-updates"

  readonly property string script: Qt.resolvedUrl("bin/aur-updates").toString().replace("file://", "")
  readonly property int intervalMs: {
    var hours = Math.round(Number(setting("intervalHours", 1)))
    if (!isFinite(hours) || hours < 1) hours = 1
    if (hours > 24) hours = 24
    return hours * 3600000
  }
  readonly property string updateCommand: String(setting("updateCommand", "yay -Sua"))

  // nf-linux-archlinux: the Arch logo from the Nerd Font the bar renders in.
  readonly property string glyphArch: "\uf303"

  // ------------------------------------------------------------------ state

  property bool checking: false
  property int count: 0
  property var packages: []
  property string error: ""
  property real lastChecked: 0
  property bool pending: false

  readonly property bool hasUpdates: count > 0

  // ------------------------------------------------------- panel integration

  // Bar.findPanelWidget requires open/close/opened on the bar-widget root, and
  // the popout coordinator compares against the slot's active item, so this
  // widget (not the nested panel) is the panel's identity.
  property var panelItem: null

  readonly property bool opened: panelItem ? panelItem.opened === true : false
  readonly property bool popoutSwitchClosing: panelItem ? panelItem.popoutSwitchClosing === true : false

  function open() { if (panelItem && panelItem.openFromHotkey) panelItem.openFromHotkey() }
  function close() { if (panelItem && panelItem.close) panelItem.close() }
  function togglePanel() { if (panelItem && panelItem.toggle) panelItem.toggle() }
  function closeForPopoutSwitch() { if (panelItem) panelItem.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    panelItem = target
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  function runUpdate() {
    if (!root.bar) return
    root.bar.run("omarchy-launch-floating-terminal-with-presentation " + root.updateCommand)
  }

  // ---------------------------------------------------------------- polling

  function refresh() {
    if (proc.running) {
      pending = true
      return
    }
    pending = false
    checking = true
    proc.command = [root.script]
    proc.running = true
  }

  function applyResult(text) {
    checking = false
    var d = null
    try {
      d = JSON.parse(text || "{}")
    } catch (e) {
      d = null
    }
    if (!d) {
      error = "Risposta non valida"
      return
    }
    count = Math.max(0, Math.round(Number(d.count) || 0))
    packages = Array.isArray(d.packages) ? d.packages : []
    error = String(d.error || "")
    lastChecked = Number(d.checked) || 0
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "neuromante.aur-updates"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyphArch
    active: root.hasUpdates
    activeColor: root.bar ? root.bar.urgent : Color.urgent
    tooltipText: root.tooltipText
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.togglePanel()
      else if (b === Qt.MiddleButton) root.refresh()
    }
  }

  readonly property string tooltipText: {
    if (root.error !== "") return "AUR: " + root.error
    if (root.checking && root.packages.length === 0) return "AUR: controllo in corso…"
    if (!root.hasUpdates) return "AUR: nessun aggiornamento"
    var lines = ["AUR: " + root.count + " pacchetti aggiornabili"]
    for (var i = 0; i < Math.min(root.packages.length, 12); i++) {
      var p = root.packages[i]
      lines.push(p.name + "  " + p.current + " → " + p.latest)
    }
    if (root.packages.length > 12) lines.push("…")
    return lines.join("\n")
  }

  // Count badge, independent of the popup's own open state.
  Rectangle {
    visible: root.count > 0
    anchors.top: button.top
    anchors.right: button.right
    z: 10

    readonly property string countText: root.count > 9 ? "9+" : String(root.count)

    implicitWidth: Math.max(Style.space(12), badgeLabel.implicitWidth + Style.space(5))
    implicitHeight: Style.space(12)
    radius: height / 2
    color: root.bar ? root.bar.urgent : Color.urgent
    border.width: 1
    border.color: root.bar ? root.bar.background : "transparent"

    Text {
      id: badgeLabel
      anchors.centerIn: parent
      text: parent.countText
      color: Color.background
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption * 0.72
      font.bold: true
    }
  }

  // Recurring check. A separate short one-shot lets the shell settle at login
  // before the first (network-bound) query.
  Timer {
    interval: root.intervalMs
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: initialTimer
    interval: 5000
    repeat: false
    onTriggered: root.refresh()
  }

  Component.onCompleted: initialTimer.start()

  Process {
    id: proc
    command: []
    onRunningChanged: {
      if (proc.running) {
        stallTimer.restart()
      } else {
        stallTimer.stop()
        if (root.pending) root.refresh()
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyResult(text)
    }
  }

  // A hung AUR query cannot be re-run while its Process is alive, so give up
  // on one that overstays and report it instead of spinning forever.
  Timer {
    id: stallTimer
    interval: 150000
    onTriggered: {
      proc.running = false
      root.checking = false
      root.error = "Timeout nella query AUR"
    }
  }
}
