// 3.3 check: with the keyboard up, does the field end up under the status bar? Same page
// as edit-bubble.qml; logs the field's window rectangle, the keyboard rectangle and the
// orientation whenever they change.
import QtQuick 2.0
import com.nokia.meego 2.0

PageStackWindow {
    id: window
    initialPage: Page {
        TextField {
            id: field
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            text: "Paste into these words"
            onActiveFocusChanged: console.log(Date.now() % 100000, "FIELD activeFocus", activeFocus)
        }
        Timer {
            interval: 200; repeat: true; running: true
            property string last
            onTriggered: {
                var p = field.mapToItem(null, 0, 0), q = field.mapToItem(null, field.width, field.height)
                var s = "field window x " + Math.round(Math.min(p.x, q.x)) + "-" + Math.round(Math.max(p.x, q.x))
                      + " y " + Math.round(Math.min(p.y, q.y)) + "-" + Math.round(Math.max(p.y, q.y))
                      + " | sip " + inputContext.softwareInputPanelVisible + " " + inputContext.softwareInputPanelRect
                      + " | orientation " + screen.currentOrientation + " rotation " + screen.rotation
                if (s != last) { console.log(Date.now() % 100000, "WATCH", s); last = s }
            }
        }
    }
}
