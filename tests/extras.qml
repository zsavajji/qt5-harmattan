// Phase 4 extras check: QtGraphicalEffects (two-texture effects hit the SGX quirk), Qt Quick
// Controls 2, WebSockets and a WebP image. Run with the dev tree's QML2_IMPORT_PATH.
import QtQuick 2.15
import QtGraphicalEffects 1.15
import QtQuick.Controls 2.15
import QtWebSockets 1.15

Rectangle {
    width: 480; height: 854; color: "#dde"
    Column {
        x: 20; y: 20; spacing: 18
        Row {
            spacing: 24
            Rectangle { id: box; width: 80; height: 80; radius: 12; color: "steelblue"; visible: false }
            DropShadow { width: 80; height: 80; source: box; horizontalOffset: 6; verticalOffset: 6; radius: 8; samples: 17; color: "#80000000" }
            FastBlur { width: 80; height: 80; source: box; radius: 16 }
            Glow { width: 80; height: 80; source: box; radius: 10; samples: 17; color: "orange" }
        }
        Row {
            spacing: 24
            Image { id: pic; width: 80; height: 80; source: "file:///usr/share/themes/blanco/meegotouch/icons/icon-l-camera.png"; visible: false }
            Rectangle { id: circle; width: 80; height: 80; radius: 40; visible: false }
            OpacityMask { width: 80; height: 80; source: pic; maskSource: circle }
            LinearGradient { width: 80; height: 80; start: Qt.point(0, 0); end: Qt.point(80, 80)
                gradient: Gradient { GradientStop { position: 0; color: "red" } GradientStop { position: 1; color: "blue" } } }
            Colorize { width: 80; height: 80; source: pic; hue: 0.3; saturation: 1; lightness: 0 }
        }
        Image { source: "file:///home/user/qt5tests/test.webp" }
        Button { text: "Controls 2 button" }
        Switch { text: "Switch"; checked: true }
        Slider { width: 400; value: 0.3 }
        Text {
            id: wsText; font.pixelSize: 22; text: "WebSocket: connecting"
            WebSocket {
                url: "wss://ws.postman-echo.com/raw"; active: true
                // The text is off-screen in landscape: the result goes to the log too.
                onStatusChanged: {
                    console.log("WebSocket status", status, errorString)
                    if (status === WebSocket.Open) sendTextMessage("hello from Qt 5")
                    else if (status === WebSocket.Error) wsText.text = "WebSocket error: " + errorString
                }
                onTextMessageReceived: { console.log("WebSocket echo:", message); wsText.text = "WebSocket echo: " + message }
            }
        }
    }
}
