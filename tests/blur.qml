// Phase 4 extras check: the blur effects alone (FastBlur rendered nothing in extras.qml).
import QtQuick 2.15
import QtGraphicalEffects 1.15

Rectangle {
    width: 854; height: 480; color: "#dde"
    Rectangle { id: box; width: 120; height: 120; radius: 12; color: "steelblue"; visible: false
        Text { anchors.centerIn: parent; text: "Qt"; font.pixelSize: 48; color: "white" } }
    Row {
        x: 20; y: 40; spacing: 30
        FastBlur { width: 120; height: 120; source: box; radius: 16; Component.onCompleted: console.log("FastBlur") }
        GaussianBlur { width: 120; height: 120; source: box; radius: 8; samples: 17 }
        RecursiveBlur { width: 120; height: 120; source: box; radius: 7.5; loops: 4 }
        Item { width: 120; height: 120; ShaderEffectSource { anchors.fill: parent; sourceItem: box } }
    }
}
