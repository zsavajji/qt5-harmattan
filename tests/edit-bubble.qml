// 3.3 check: a tap in a focused field opens the edit bubble (Paste) and a double tap selects
// a word. Driven by scripts/xtouch; the clipboard gets text at start.
import QtQuick 2.0
import com.nokia.meego 2.0

PageStackWindow {
    initialPage: Page {
        TextField {
            id: field
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20; topMargin: 200 }
            text: "Paste into these words"
            onActiveFocusChanged: console.log(Date.now() % 100000, "FIELD activeFocus", activeFocus)
            onSelectedTextChanged: console.log(Date.now() % 100000, "FIELD selected [" + selectedText + "]")
            Component.onCompleted: { selectAll(); copy(); select(0, 0) }
        }
        Timer {
            interval: 100; repeat: true; running: true
            property string last
            onTriggered: {
                var root = field
                while (root.parent && root.objectName != "windowContent") root = root.parent
                var s = ""
                for (var i = 0; i < root.children.length; ++i) {
                    var c = root.children[i]
                    if (c.textInput !== undefined && c.state !== undefined) s += "bubble " + c.state + " valid " + c.valid + " "
                }
                if (s != last) { console.log(Date.now() % 100000, "POPUPS", s); last = s }
            }
        }
    }
}
