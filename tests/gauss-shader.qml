// Phase 4 extras check: compile QtGraphicalEffects' generated Gaussian blur shaders in a plain
// ShaderEffect and print its status and log (GaussianBlur drew nothing, with no warning).
import QtQuick 2.15
import QtGraphicalEffects.private 1.15

Rectangle {
    width: 854; height: 480; color: "#dde"
    Rectangle { id: box; width: 120; height: 120; color: "steelblue"; visible: false }
    ShaderEffect {
        id: effect
        width: 120; height: 120
        property variant source: ShaderEffectSource { sourceItem: box }
        property real spread: 1
        property vector2d dirstep: Qt.vector2d(1 / 120, 0)
        property var shaders: ShaderBuilder.gaussianBlur({ radius: 8, deviation: 3, alphaOnly: false, masked: false, fallback: false })
        vertexShader: shaders.vertexShader
        fragmentShader: shaders.fragmentShader
        onStatusChanged: console.log("status", status, "log", log)
        Component.onCompleted: { console.log("VERTEX\n" + shaders.vertexShader); console.log("FRAGMENT\n" + shaders.fragmentShader) }
    }
}
