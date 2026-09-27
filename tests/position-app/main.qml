import QtQuick 2.0
import QtPositioning 5.4

// The position from positioningd, once a second; tap to stop and start.
Rectangle {
    width: 854; height: 480; color: "black"
    PositionSource {
        id: source
        active: true
        updateInterval: 1000
        onPositionChanged: console.log("position", position.coordinate, "accuracy",
                                       position.horizontalAccuracy, "at", position.timestamp)
        onSourceErrorChanged: console.log("source error", sourceError)
        Component.onCompleted: console.log("source", name, "valid", valid,
                                           "methods", supportedPositioningMethods)
    }
    MouseArea { anchors.fill: parent; onClicked: source.active = !source.active }
    Column {
        anchors { left: parent.left; top: parent.top; margins: 24 }
        spacing: 12
        Repeater {
            model: [
                source.name + (source.active ? ", active" : ", stopped") + ", error " + source.sourceError,
                "methods " + source.supportedPositioningMethods,
                source.position.latitudeValid ? source.position.coordinate.toString() : "no fix yet",
                "accuracy " + source.position.horizontalAccuracy.toFixed(0) + " m, speed "
                    + (source.position.speedValid ? source.position.speed.toFixed(1) + " m/s" : "-"),
                "time " + source.position.timestamp,
                satellites
            ]
            Text { color: "white"; font.pixelSize: 26; text: modelData }
        }
    }
}
