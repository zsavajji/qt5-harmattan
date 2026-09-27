import QtQuick 2.0
import QtPositioning 5.4

// PositionSource without the Location credential (qmlscene from ssh): expect AccessError (1).
Rectangle {
    width: 854; height: 480; color: "black"
    PositionSource {
        id: source
        active: true
        onSourceErrorChanged: console.log("source error", sourceError)
        onPositionChanged: console.log("position", position.coordinate)
        Component.onCompleted: console.log("source", name, "valid", valid, "methods",
                                           supportedPositioningMethods, "error", sourceError)
    }
    Text { color: "white"; font.pixelSize: 28; text: source.name + " error " + source.sourceError }
}
