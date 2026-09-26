import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Detail popup for the AUR update widget: lists every installed AUR package
// with an update, showing the installed and the latest version, and offers a
// button that launches the configured update command in a floating terminal.
Panel {
  id: root
  moduleName: "neuromante.aur-updates"
  ipcTarget: ""
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property var barObj: root.bar
  readonly property color fg: barObj ? barObj.foreground : Color.foreground
  readonly property color dim: Qt.darker(fg, 1.4)
  readonly property color accent: Color.accent
  readonly property string family: barObj ? barObj.fontFamily : Style.font.family

  readonly property var packages: hostWidget ? hostWidget.packages : []
  readonly property int count: hostWidget ? hostWidget.count : 0
  readonly property bool checking: hostWidget ? hostWidget.checking : false
  readonly property string error: hostWidget ? hostWidget.error : ""
  readonly property string updateCommand: String(setting("updateCommand", "yay -Sua"))

  function open() {
    root.controller.show()
    if (root.hostWidget && root.hostWidget.refresh) root.hostWidget.refresh()
  }

  function openFromHotkey() { root.open() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function refreshNow() {
    if (root.hostWidget && root.hostWidget.refresh) root.hostWidget.refresh()
  }

  function runUpdate() {
    if (root.hostWidget && root.hostWidget.runUpdate) root.hostWidget.runUpdate()
    root.close()
  }

  // ---------------------------------------------------------------- changelog

  // Recent upstream commit subjects per package, resolved lazily while the
  // popup is open and cached by bin/aur-changelog. The map is keyed by package
  // name. `expandedChangelogs` remembers which excerpts the user opened.
  property var changelogs: ({})
  property var expandedChangelogs: ({})
  property bool changelogsLoading: false
  property bool changelogsPending: false

  readonly property string changelogScript:
    Qt.resolvedUrl("bin/aur-changelog").toString().replace("file://", "")

  function hasChangelog(name) {
    var entry = root.changelogs[name]
    return !!(entry && entry.available && entry.commits && entry.commits.length > 0)
  }

  function isChangelogExpanded(name) {
    return root.expandedChangelogs[name] === true
  }

  function toggleChangelog(name) {
    var next = {}
    for (var key in root.expandedChangelogs) next[key] = root.expandedChangelogs[key]
    next[name] = !root.isChangelogExpanded(name)
    root.expandedChangelogs = next
  }

  function changelogText(name) {
    var entry = root.changelogs[name]
    if (!entry || !entry.commits) return ""
    var lines = []
    for (var i = 0; i < entry.commits.length; i++) {
      var subject = String(entry.commits[i].subject || "")
      if (subject !== "") lines.push("• " + subject)
    }
    return lines.join("\n")
  }

  function fetchChangelogs() {
    if (changelogProc.running) {
      root.changelogsPending = true
      return
    }
    var names = []
    for (var i = 0; i < root.packages.length; i++) {
      var name = String(root.packages[i].name || "")
      if (name !== "") names.push(name)
    }
    if (names.length === 0) {
      root.changelogs = {}
      return
    }
    root.changelogsLoading = true
    changelogProc.command = [root.changelogScript].concat(names)
    changelogProc.running = true
  }

  onOpenedChanged: {
    if (root.opened) root.fetchChangelogs()
  }

  onPackagesChanged: {
    // A fresh update list invalidates the excerpts. Only fetch while visible.
    if (root.opened) root.fetchChangelogs()
    else root.changelogs = {}
  }

  property Process changelogProc: Process {
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = null
        try {
          parsed = JSON.parse(text || "{}")
        } catch (e) {
          parsed = null
        }
        root.changelogs = (parsed && typeof parsed === "object") ? parsed : {}
      }
    }
    onRunningChanged: {
      if (!running) {
        root.changelogsLoading = false
        if (root.changelogsPending) {
          root.changelogsPending = false
          root.fetchChangelogs()
        }
      }
    }
  }

  function packageUrl(name) {
    var pkg = String(name || "")
    if (pkg === "") return ""
    return "https://aur.archlinux.org/packages/" + encodeURIComponent(pkg)
  }

  function openPackage(name) {
    var url = root.packageUrl(name)
    if (url !== "") root.openExternal(url)
  }

  // Open an http(s) URL in the default browser. QDesktopServices can silently
  // no-op under some session setups, so fall back to a detached xdg-open when
  // it reports failure.
  property Process xdgOpenProcess: Process {}
  function openExternal(url) {
    var u = String(url || "")
    if (!/^https?:\/\//.test(u)) return
    if (!Qt.openUrlExternally(u)) {
      xdgOpenProcess.command = ["xdg-open", u]
      xdgOpenProcess.running = true
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(470))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTextKey: function(t) { if (t === "r") root.refreshNow() }
      onMoveRequested: function(dx, dy) {
        var step = dy * Style.space(44)
        flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + step))
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: content
          width: flick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            iconComponent: archIcon
            title: "Aggiornamenti AUR"
            meta: root.error !== ""
              ? root.error
              : (root.checking
                ? "Controllo in corso…"
                : (root.count > 0
                  ? root.count + (root.count === 1 ? " pacchetto aggiornabile" : " pacchetti aggiornabili")
                  : "Tutti i pacchetti AUR sono aggiornati"))
            foreground: root.fg
            fontFamily: root.family
          }

          Rectangle {
            width: parent.width
            height: Style.spacing.hairline
            color: root.fg
            opacity: 0.12
          }

          // ---- Empty / error / checking state -----------------------------
          Text {
            visible: root.count === 0
            width: parent.width
            topPadding: Style.space(6)
            bottomPadding: Style.space(6)
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: root.error !== ""
              ? root.error
              : (root.checking ? "Interrogazione dell'AUR in corso…" : "Nessun aggiornamento disponibile.")
            color: root.dim
            font.family: root.family
            font.pixelSize: Style.font.bodySmall
            font.italic: true
          }

          // ---- Package list ----------------------------------------------
          Column {
            visible: root.count > 0
            width: parent.width
            spacing: 0

            Repeater {
              model: root.packages

              Column {
                required property var modelData
                required property int index

                width: content.width
                spacing: 0

                // ---- package name (AUR link) + versions -------------------
                Item {
                  width: parent.width
                  height: Style.space(42)

                  // Package name is a hyperlink to its AUR page; clicking it
                  // opens the default browser.
                  Text {
                    id: nameText
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(4)
                    anchors.right: versionRow.left
                    anchors.rightMargin: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: modelData.name
                    elide: Text.ElideRight
                    color: nameArea.containsMouse ? root.accent : root.fg
                    font.family: root.family
                    font.pixelSize: Style.font.body
                    font.underline: nameArea.containsMouse

                    Behavior on color { ColorAnimation { duration: 100 } }

                    MouseArea {
                      id: nameArea
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.openPackage(modelData.name)
                    }

                    PanelToolTip {
                      visible: nameArea.containsMouse && root.packageUrl(modelData.name) !== ""
                      text: root.packageUrl(modelData.name)
                      fontFamily: root.family
                    }
                  }

                  Text {
                    id: latestText
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(4)
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: modelData.latest !== "" ? modelData.latest : "—"
                    color: root.accent
                    font.family: root.family
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }

                  Row {
                    id: versionRow
                    anchors.right: latestText.left
                    anchors.rightMargin: Style.space(6)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Text {
                      textFormat: Text.PlainText
                      text: modelData.current
                      color: root.dim
                      font.family: root.family
                      font.pixelSize: Style.font.bodySmall
                      anchors.verticalCenter: parent.verticalCenter
                      elide: Text.ElideRight
                      width: Math.min(implicitWidth, Style.space(130))
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: "→"
                      color: root.dim
                      font.family: root.family
                      font.pixelSize: Style.font.bodySmall
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }
                }

                // ---- changelog excerpt (max 2 lines, expandable) ----------
                Item {
                  width: parent.width
                  visible: root.hasChangelog(modelData.name)
                  height: visible ? implicitHeight : 0
                  implicitHeight: changelogColumn.implicitHeight + Style.space(10)

                  Column {
                    id: changelogColumn
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(4)
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(4)
                    anchors.top: parent.top
                    anchors.topMargin: Style.space(2)
                    spacing: Style.space(2)

                    Row {
                      spacing: Style.space(4)

                      Text {
                        textFormat: Text.PlainText
                        text: "Changelog"
                        color: root.dim
                        font.family: root.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Text {
                        textFormat: Text.PlainText
                        text: root.isChangelogExpanded(modelData.name) ? "▴" : "▾"
                        color: root.dim
                        font.family: root.family
                        font.pixelSize: Style.font.caption
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }

                    Text {
                      width: parent.width
                      textFormat: Text.PlainText
                      wrapMode: Text.WordWrap
                      text: root.changelogText(modelData.name)
                      maximumLineCount: root.isChangelogExpanded(modelData.name) ? 1000 : 2
                      elide: root.isChangelogExpanded(modelData.name) ? Text.ElideNone : Text.ElideRight
                      color: Qt.darker(root.fg, 1.25)
                      font.family: root.family
                      font.pixelSize: Style.font.bodySmall
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleChangelog(modelData.name)
                  }
                }

                Rectangle {
                  width: parent.width
                  height: Style.spacing.hairline
                  color: root.fg
                  opacity: 0.08
                  visible: index < root.packages.length - 1
                }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: Style.spacing.hairline
            color: root.fg
            opacity: 0.12
            visible: root.count > 0
          }

          // ---- Action ----------------------------------------------------
          Button {
            width: parent.width
            text: root.count > 0 ? "Aggiorna con yay" : "Controlla adesso"
            iconText: root.count > 0 ? "\uf303" : "\uf021"
            foreground: root.fg
            accent: root.accent
            fontFamily: root.family
            onClicked: {
              if (root.count > 0) root.runUpdate()
              else root.refreshNow()
            }
          }

          Text {
            width: parent.width
            visible: root.count > 0
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: "$ " + root.updateCommand
            color: root.dim
            font.family: root.family
            font.pixelSize: Style.font.caption
            opacity: 0.8
          }
        }
      }
    }
  }

  Component {
    id: archIcon
    Text {
      text: "\uf303"
      color: root.fg
      font.family: root.family
      font.pixelSize: Style.font.displayLarge
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }
  }

}
