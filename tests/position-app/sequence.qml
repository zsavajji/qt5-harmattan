import QtQuick 2.0
import QtPositioning 5.4

// Lifecycle run for the positioningd plugin (qt5-positiontest sequence.qml): start, stop,
// restart, interval and method changes, a single update with a timeout, and sources destroyed
// while running. Everything is logged; "sequence done" at the end (then kill the app: Qt.quit()
// isn't connected in this QQuickView). The single update waits for its timeout (the plugin's
// default, 120 s: QML's update() takes none in Qt 5.15) or a position.
Rectangle {
    width: 854; height: 480; color: "black"
    property int step: 0
    Loader {
        id: loader
        sourceComponent: PositionSource {
            updateInterval: 1000
            active: true
            onPositionChanged: { console.log("position", position.coordinate, position.horizontalAccuracy); timer.running = true }
            onSourceErrorChanged: console.log("source error", sourceError)
            onActiveChanged: console.log("active", active)
            onUpdateTimeout: { console.log("update timeout"); timer.running = true }
            onUpdateIntervalChanged: console.log("interval", updateInterval)
            onPreferredPositioningMethodsChanged: console.log("preferred", preferredPositioningMethods)
            Component.onCompleted: console.log("created", name, "valid", valid, "methods",
                                               supportedPositioningMethods, "error", sourceError,
                                               "last known", position.coordinate)
        }
    }
    Timer {
        id: timer
        interval: 4000; repeat: true; running: true
        onTriggered: {
            var s = loader.item
            step++
            console.log("step", step)
            switch (step) {
            case 1: s.stop(); break
            case 2: s.start(); break
            case 3: s.updateInterval = 5000; s.preferredPositioningMethods = PositionSource.NonSatellitePositioningMethods; break
            case 4: s.preferredPositioningMethods = PositionSource.AllPositioningMethods; s.updateInterval = 1000; break
            case 5: s.stop(); timer.running = false; s.update(); break   // a single update
            case 8: loader.active = false; break                // destroyed while stopped
            case 9: loader.active = true; break
            case 10: loader.active = false; break               // destroyed while active
            case 11: loader.active = true; break
            case 13: console.log("sequence done"); break
            }
        }
    }
    Text { color: "white"; font.pixelSize: 28; text: "step " + step }
}
