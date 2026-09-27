import QtQuick 2.0
import QtFeedback 5.0

// Haptics check (task 6): plays each theme effect every 2 s, showing its name; a tap plays Press.
Rectangle {
    width: 854; height: 480; color: "black"
    property var names: ["Press", "Release", "PressWeak", "ReleaseWeak", "DragStart",
                         "DragDropInZone", "Move", "Appear", "Disappear"]
    property int i: 0
    ThemeEffect { id: effect }
    Timer {
        interval: 2000; repeat: true; running: true
        onTriggered: {
            if (i >= names.length) { label.text = "done"; stop(); return }
            effect.effect = ThemeEffect[names[i]]
            effect.play()
            console.log("played", names[i], "supported", effect.supported)
            label.text = names[i++]
        }
    }
    Text { id: label; color: "white"; font.pixelSize: 64; anchors.centerIn: parent }
    MouseArea { anchors.fill: parent; onPressed: effect.play(ThemeEffect.Press) }
}
