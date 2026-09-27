import QtQuick 2.0
import QtMultimedia 5.4

// Race check: the camera starts 3 s after the page is up, not while the window and its GL
// context are being created. No VideoOutput (fakesink viewfinder).
Rectangle {
    width: 854; height: 480; color: "black"
    Camera {
        id: camera
        cameraState: Camera.UnloadedState
        onCameraStatusChanged: console.log("camera status", cameraStatus)
        onErrorChanged: console.log("camera error", errorCode, errorString)
    }
    Timer { interval: 3000; running: true; onTriggered: { console.log("starting camera"); camera.cameraState = Camera.ActiveState } }
    Text { color: "white"; font.pixelSize: 40; anchors.centerIn: parent; text: "status " + camera.cameraStatus }
}
