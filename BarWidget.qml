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

  property bool micEnabled: true
  property bool cameraEnabled: true
  property bool cameraSliderBlack: true
  property string micIcon: ""
  property string cameraIcon: ""
  property string micState: "error"
  property string cameraState: "error"
  property string micTooltip: "Framework microphone privacy state unavailable"
  property string cameraTooltip: "Framework camera privacy state unavailable"
  property bool popupOpen: false

  // Collapse the whole slot only when both indicators are off. The bar uses
  // the widget's visible property to decide whether it takes up space.
  visible: root.micEnabled || root.cameraEnabled
  implicitWidth: icons.item ? icons.item.implicitWidth : 0
  implicitHeight: icons.item ? icons.item.implicitHeight : 0

  function colorFor(state) {
    if (state === "microphone-active" || state === "camera-active") return "#30d158"
    if (state === "microphone-ready" || state === "camera-ready") return "#61afef"
    if (state === "microphone-blocked" || state === "camera-blocked") return "#a55555"
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
      var mic = data.microphone || {}
      var camera = data.camera || {}

      root.micIcon = String(mic.icon || "")
      root.micState = String(mic.state || "error")
      root.micTooltip = String(mic.tooltip || "Framework microphone privacy state unavailable")

      root.cameraIcon = String(camera.icon || "")
      root.cameraState = String(camera.state || "error")
      root.cameraTooltip = String(camera.tooltip || "Framework camera privacy state unavailable")
      if (camera.slider_black !== undefined && camera.slider_black !== null) {
        root.cameraSliderBlack = camera.slider_black === true
      }

      var visibility = mic.visibility || camera.visibility || {}
      root.micEnabled = visibility.microphone !== false
      root.cameraEnabled = visibility.camera !== false
    } catch (error) {
      root.micIcon = ""
      root.cameraIcon = ""
      root.micState = "error"
      root.cameraState = "error"
      root.micTooltip = "Framework privacy state unavailable\n" + error
      root.cameraTooltip = root.micTooltip
      root.micEnabled = true
      root.cameraEnabled = true
    }
  }

  // Both the popup and the CLI write the same state file.
  function setEnabled(which, value) {
    setProc.command = [cliScript, value ? "on" : "off", which]
    if (!setProc.running) setProc.running = true
  }

  function setCameraSlider(black) {
    setProc.command = [cliScript, "slider", "camera", black ? "black" : "red"]
    if (!setProc.running) setProc.running = true
  }

  function handlePress(which, mouseButton) {
    if (mouseButton === Qt.RightButton) {
      setEnabled(which, !(which === "camera" ? root.cameraEnabled : root.micEnabled))
    } else {
      root.popupOpen = !root.popupOpen
    }
  }

  Component.onCompleted: refresh()

  Process {
    id: statusProc
    command: [statusScript]
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

  Loader {
    id: icons
    sourceComponent: root.vertical ? verticalIcons : horizontalIcons
  }

  Component {
    id: horizontalIcons
    Row {
      spacing: 0

      BarIconButton {
        visible: root.micEnabled
        bar: root.bar
        text: root.micIcon
        foreground: root.colorFor(root.micState)
        tooltipText: root.micTooltip
        onPressed: function(button) { root.handlePress("microphone", button) }
      }

      BarIconButton {
        visible: root.cameraEnabled
        bar: root.bar
        text: root.cameraIcon
        foreground: root.colorFor(root.cameraState)
        tooltipText: root.cameraTooltip
        onPressed: function(button) { root.handlePress("camera", button) }
      }
    }
  }

  Component {
    id: verticalIcons
    Column {
      spacing: 0

      BarIconButton {
        visible: root.micEnabled
        bar: root.bar
        text: root.micIcon
        foreground: root.colorFor(root.micState)
        tooltipText: root.micTooltip
        onPressed: function(button) { root.handlePress("microphone", button) }
      }

      BarIconButton {
        visible: root.cameraEnabled
        bar: root.bar
        text: root.cameraIcon
        foreground: root.colorFor(root.cameraState)
        tooltipText: root.cameraTooltip
        onPressed: function(button) { root.handlePress("camera", button) }
      }
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

      Toggle {
        width: parent.width
        label: "Camera slider"
        description: "Black = camera available, red = camera blocked"
        checked: root.cameraSliderBlack
        onClicked: root.setCameraSlider(!root.cameraSliderBlack)
      }

      Text {
        textFormat: Text.PlainText
        text: "Right-click an icon to toggle it directly.\nCLI: framework-privacy toggle microphone|camera\n     framework-privacy slider camera black|red"
        color: Qt.darker(Commons.Color.foreground, 1.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        width: parent.width
      }
    }
  }
}
