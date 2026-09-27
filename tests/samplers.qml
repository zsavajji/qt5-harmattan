// SGX530 check: a ShaderEffect with several samplers (FastBlur uses six). Each third of the
// item shows one texture: expected red | green | blue.
import QtQuick 2.15

Rectangle {
    width: 854; height: 480; color: "#dde"
    Rectangle { id: r; width: 64; height: 64; color: "red"; visible: false }
    Rectangle { id: g; width: 48; height: 48; color: "lime"; visible: false }
    Rectangle { id: b; width: 32; height: 32; color: "blue"; visible: false }
    ShaderEffect {
        x: 40; y: 100; width: 360; height: 120
        property variant t1: ShaderEffectSource { sourceItem: r }
        property variant t2: ShaderEffectSource { sourceItem: g }
        property variant t3: ShaderEffectSource { sourceItem: b }
        fragmentShader: "
            uniform lowp sampler2D t1; uniform lowp sampler2D t2; uniform lowp sampler2D t3;
            varying highp vec2 qt_TexCoord0; uniform lowp float qt_Opacity;
            void main() {
                lowp vec4 c = qt_TexCoord0.x < 0.333 ? texture2D(t1, qt_TexCoord0)
                            : qt_TexCoord0.x < 0.666 ? texture2D(t2, qt_TexCoord0) : texture2D(t3, qt_TexCoord0);
                gl_FragColor = c * qt_Opacity;
            }"
    }
    ShaderEffect {   // the same, sampling all three everywhere and summing thirds by mask
        x: 440; y: 100; width: 360; height: 120
        property variant t1: ShaderEffectSource { sourceItem: r }
        property variant t2: ShaderEffectSource { sourceItem: g }
        property variant t3: ShaderEffectSource { sourceItem: b }
        fragmentShader: "
            uniform lowp sampler2D t1; uniform lowp sampler2D t2; uniform lowp sampler2D t3;
            varying highp vec2 qt_TexCoord0; uniform lowp float qt_Opacity;
            void main() {
                lowp vec4 a = texture2D(t1, qt_TexCoord0), b = texture2D(t2, qt_TexCoord0), c = texture2D(t3, qt_TexCoord0);
                lowp float x = qt_TexCoord0.x;
                gl_FragColor = (x < 0.333 ? a : x < 0.666 ? b : c) * qt_Opacity;
            }"
    }
}
