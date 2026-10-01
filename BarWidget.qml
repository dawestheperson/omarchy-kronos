import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Kronos in the bar. The icon's tooltip says how much is remembered and how
// warm; a left click opens the Kronos app, a right click runs its doctor and
// reports the result. Everything comes from `kronos status --json`, so the
// widget holds no state of its own.
BarWidget {
  id: root
  moduleName: "dawestheperson.kronos"

  readonly property string command: String(setting("command", "kronos"))
  readonly property int refreshIntervalSec: Math.max(30, Number(setting("refreshIntervalSec", 300)) || 300)
  property var status: null
  property bool missing: false

  readonly property string summary: {
    if (missing) return "Kronos is not installed\nRight click for setup instructions"
    if (!status) return "Kronos"
    return "Kronos: " + status.memories + " memories\n"
      + status.hot + " hot · " + status.warm + " warm · " + status.cold + " cold\n"
      + status.today + " exchanges today"
      + (status.recall ? "" : "\nAutomatic recall is off")
  }

  function quote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function openApp() {
    if (!root.bar) return
    root.bar.run("omarchy-launch-tui " + quote(command))
  }

  function repair() {
    if (!root.bar) return
    if (missing) {
      root.bar.run("xdg-open https://github.com/dawestheperson/kronos#install")
      return
    }
    // Report only what needed attention; "fixed" lines say what was repaired.
    root.bar.run("out=$(" + quote(command) + " doctor --fix 2>&1 | grep -vE '^(info|ok) ' | head -5); "
      + "omarchy-notification-send \"Kronos\" \"${out:-Everything is working.}\"")
    Qt.callLater(refresh)
  }

  Process {
    id: statusProc
    command: [root.command, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.status = JSON.parse(String(text || "").trim())
          root.missing = false
        } catch (e) {
          root.status = null
        }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.status === null) root.missing = true
    }
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰋚"
    dimmed: root.missing
    tooltipText: root.summary
    onPressed: function(b) {
      if (b === Qt.RightButton) root.repair()
      else if (b === Qt.MiddleButton) root.refresh()
      else root.openApp()
    }
  }
}
