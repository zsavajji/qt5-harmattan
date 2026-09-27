// 3.3 check: long press in a field opens the magnifier, which follows the finger.
// Driven by scripts/xtouch; the log shows the magnifier's parts.
import QtQuick 2.0
import com.nokia.meego 2.0

PageStackWindow {
    initialPage: Page {
        TextField {
            id: field
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20; topMargin: 200 }
            text: "Magnify these words please"
            onCursorPositionChanged: console.log("FIELD cursor", cursorPosition)
        }
        Timer {
            interval: 500; repeat: true; running: true
            onTriggered: {
                var root = field
                while (root.parent && root.objectName != "windowContent") root = root.parent
                for (var i = 0; i < root.children.length; ++i) {
                    var m = root.children[i]
                    if (m.xCenter === undefined || !m.visible) continue
                    var s = "MAGNIFIER at " + m.x + "," + m.y + " center " + m.xCenter + "," + m.yCenter + ":"
                    for (var j = 0; j < m.children.length; ++j) {
                        var c = m.children[j]
                        s += " [" + c + " " + c.width + "x" + c.height + " visible " + c.visible
                        if (c.status !== undefined) s += " status " + c.status + " " + c.sourceSize
                        s += "]"
                    }
                    console.log(s)
                }
            }
        }
    }
}
