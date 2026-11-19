import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "thatkes.framework-privacy"

  readonly property string pluginDir: Quickshell.env("HOME")
    + "/.config/omarchy/plugins/thatkes.framework-privacy"
  readonly property string statusScript: pluginDir + "/status.py"
  readonly property string cliScript: pluginDir + "/framework-privacy"

  property string device: normalizeDevice(setting("mode", "microphone"))
  property bool enabled: true
  property bool micEnabled: true
  property bool cameraEnabled: true
  property string icon: ""
  property string indicatorState: "error"
  property string statusText: "Framework privacy state unavailable"
  property bool popupOpen: false

  // The bar collapses the slot when the widget is not visible, so switching an
  // indicator off really removes its icon instead of leaving a blank space.
  visible: root.enabled
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property color iconColor: {
    if (indicatorState === "microphone-active" || indicatorState === "camera-active")
      return "#30d158"
    if (indicatorState === "microphone-ready" || indicatorState === "camera-ready")
      return "#61afef"
    if (indicatorState === "microphone-blocked" || indicatorState === "camera-blocked")
      return "#a55555"
    return "#e5c07b"
  }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function normalizeDevice(value) {
    var mode = String(value || "").trim().toLowerCase()
    if (mode === "camera" || mode === "webcam" || mode === "cam") return "camera"
    return "microphone"
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
      root.indicatorState = String(data.state || "error")
      root.statusText = String(data.tooltip || "Framework privacy state unavailable")

      var visibility = data.visibility || {}
      root.micEnabled = visibility.microphone !== false
      root.cameraEnabled = visibility.camera !== false
      root.enabled = root.device === "camera" ? root.cameraEnabled : root.micEnabled
    } catch (error) {
      root.icon = ""
      root.indicatorState = "error"
      root.statusText = "Framework privacy state unavailable\n" + error
      root.enabled = true
    }
  }

  // Writes through the CLI so the bar and the command line share one state file.
  function setEnabled(which, value) {
    setProc.command = [cliScript, value ? "on" : "off", which]
    if (!setProc.running) setProc.running = true
  }

  Component.onCompleted: refresh()

  Process {
    id: statusProc
    command: [statusScript, root.device]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
  }

  Process {
    id: setProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.refresh()
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
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.setEnabled(root.device, !root.enabled)
      else root.popupOpen = !root.popupOpen
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: "Privacy indicators"
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
        width: parent.width
      }

      Toggle {
        width: parent.width
        label: "Microphone indicator"
        description: "Show the microphone privacy icon in the bar"
        checked: root.micEnabled
        onClicked: root.setEnabled("microphone", !root.micEnabled)
      }

      Toggle {
        width: parent.width
        label: "Camera indicator"
        description: "Show the webcam privacy icon in the bar"
        checked: root.cameraEnabled
        onClicked: root.setEnabled("camera", !root.cameraEnabled)
      }

      Text {
        textFormat: Text.PlainText
        text: "Right-click an icon to toggle it directly.\nCLI: framework-privacy toggle microphone|camera"
        color: Qt.darker(Commons.Color.foreground, 1.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        width: parent.width
      }
    }
  }
}
