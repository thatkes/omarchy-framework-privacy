import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "chalkers.framework-microphone"

  property string icon: ""
  property string state: "error"
  property string statusText: "Framework microphone privacy state unavailable"

  readonly property color iconColor: {
    if (state === "mic-active") return "#30d158"
    if (state === "mic-ready") return "#61afef"
    if (state === "mic-blocked") return "#a55555"
    return "#e5c07b"
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function parseStatus(raw) {
    var text = String(raw || "").trim()
    if (!text) return

    try {
      var data = JSON.parse(text.split("\n").pop())
      root.icon = String(data.icon || "")
      root.state = String(data.state || "error")
      root.statusText = String(data.tooltip || "Framework microphone privacy state unavailable")
    } catch (error) {
      root.icon = ""
      root.state = "error"
      root.statusText = "Framework microphone privacy state unavailable\n" + error
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()

  Process {
    id: statusProc
    command: [
      Quickshell.env("HOME") + "/.config/omarchy/plugins/chalkers.framework-microphone/status.py"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    foreground: root.iconColor
    tooltipText: root.statusText
    onPressed: root.refresh()
  }
}
