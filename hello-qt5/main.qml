import QtQuick 2.12
import QtQuick.Window 2.12

Rectangle {
    id: root
    color: "black"
    property int taps: 0
    // The display is landscape; the content turns to match the device (Screen.orientation
    // comes from sensord through the xcb plugin, 3.2).
    readonly property int angle: Screen.angleBetween(Screen.orientation, Qt.LandscapeOrientation)
    readonly property bool portrait: angle === 90 || angle === 270

    Item {
        id: content
        anchors.centerIn: parent
        width: root.portrait ? root.height : root.width
        height: root.portrait ? root.width : root.height
        rotation: root.angle

        // Keeps the scene graph busy every frame, so the frame rate shows what the GPU path can do.
        Rectangle {
            id: square
            width: 220; height: 220
            anchors.centerIn: parent
            color: "#2a7fff"
            RotationAnimator on rotation { from: 0; to: 360; duration: 3000; loops: Animation.Infinite }
        }

        // Two fingers scale the square (3.4 multitouch); one finger still taps.
        PinchArea {
            anchors.fill: parent
            pinch.target: square
            pinch.minimumScale: 0.5
            pinch.maximumScale: 3
            onPinchStarted: stats.log("pinch started, " + pinch.pointCount + " points")
            onPinchFinished: stats.log("pinch finished, scale " + square.scale.toFixed(2))

        MouseArea {
            anchors.fill: parent
            onClicked: {
                content.forceActiveFocus() // takes focus from the text box, so the keyboard closes
                root.taps++
                stats.log("tap " + root.taps + " at " + Math.round(mouse.x) + "," + Math.round(mouse.y))
            }
        }
        }

        Column {
            x: 24; y: 24
            spacing: 12
            Text { color: "white"; font.pixelSize: 32; text: "FPS: " + stats.fps }
            Text { color: "white"; font.pixelSize: 22; text: "GL_RENDERER: " + stats.renderer }
            Text { color: "white"; font.pixelSize: 32; text: "Taps: " + root.taps }
            Text { color: "white"; font.pixelSize: 22; text: "Orientation: " + root.angle + "°" }
            Rectangle {
                width: 420; height: 56
                color: "white"
                TextInput {
                    anchors.fill: parent
                    anchors.margins: 10
                    font.pixelSize: 30
                    selectByMouse: true
                    onTextChanged: stats.log("text \"" + text + "\"")
                }
            }
        }
    }
}
