import QtQuick 2.0
import QtMultimedia 5.4

// Viewfinder of the back camera; tap to take a picture, the button switches cameras.
Rectangle {
    width: 854; height: 480; color: "black"
    Camera {
        id: camera
        captureMode: Camera.CaptureStillImage
        onCameraStatusChanged: console.log("camera status", cameraStatus)
        onErrorChanged: console.log("camera error", errorCode, errorString)
        imageCapture.onImageSaved: { console.log("saved", path); info.text = path }
        imageCapture.onCaptureFailed: console.log("capture failed", message)
        Component.onCompleted: {
            console.log("cameras", JSON.stringify(QtMultimedia.availableCameras))
            console.log("availability", availability)
        }
    }
    VideoOutput { anchors.fill: parent; source: camera; fillMode: VideoOutput.PreserveAspectCrop
                  orientation: camera.orientation }
    MouseArea {
        anchors.fill: parent
        onClicked: camera.imageCapture.captureToLocation("/home/user/MyDocs/qt5-cameratest.jpg")
    }
    Rectangle {
        anchors { right: parent.right; top: parent.top; margins: 16 }
        width: 140; height: 60; radius: 8; color: "#80000000"
        Text { anchors.centerIn: parent; color: "white"; font.pixelSize: 24
               text: camera.position === Camera.FrontFace ? "Front" : "Back" }
        MouseArea { anchors.fill: parent
            onClicked: camera.position = camera.position === Camera.FrontFace ? Camera.BackFace : Camera.FrontFace }
    }
    Text { id: info; color: "white"; font.pixelSize: 20; text: "status " + camera.cameraStatus }
}
