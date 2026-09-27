// FastBlur stages on the SGX530 (FastBlur too light). Columns, 160x160 each, steelblue source:
// A level1 on screen, B effect1 (4-tap) on screen, C level2 (effect1 in an FBO),
// D a passthrough shader in an FBO, E the real FastBlur radius 1. Expected: all steelblue.
import QtQuick 2.15
import QtGraphicalEffects 1.15

Rectangle {
    width: 854; height: 480; color: "#dde"
    property string vs: "qrc:/qt-project.org/imports/QtGraphicalEffects/shaders/fastblur_internal.vert"
    property string fs: "qrc:/qt-project.org/imports/QtGraphicalEffects/shaders/fastblur_internal.frag"
    Rectangle { id: big; width: 300; height: 300; color: "steelblue"; visible: false }
    ShaderEffectSource { id: level1; width: 320; height: 320; sourceItem: big; visible: false; smooth: true }
    Row {
        x: 7; y: 160; spacing: 7
        ShaderEffectSource { width: 160; height: 160; sourceItem: big }
        ShaderEffect { width: 160; height: 160; property variant source: level1
            property real yStep: 1/height; property real xStep: 1/width; vertexShader: vs; fragmentShader: fs }
        Item { width: 160; height: 160
            ShaderEffect { id: e1; anchors.fill: parent; visible: false; property variant source: level1
                property real yStep: 1/height; property real xStep: 1/width; vertexShader: vs; fragmentShader: fs }
            ShaderEffectSource { anchors.fill: parent; sourceItem: e1 } }
        Item { width: 160; height: 160
            ShaderEffect { id: p; anchors.fill: parent; visible: false; property variant source: level1 }
            ShaderEffectSource { anchors.fill: parent; sourceItem: p } }
        FastBlur { width: 160; height: 160; source: big; radius: 1 }
    }
}
