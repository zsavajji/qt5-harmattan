// 3.3 check: why do the edit bubble's Copy/Cut do nothing? Logs focus and selection
// changes of field A, so a tap on Copy shows whether the selection is gone first.
import QtQuick 2.0
import com.nokia.meego 2.0

PageStackWindow {
    initialPage: Page {
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 20
            TextField {
                id: a
                width: parent.width
                text: "Select some of these words"
                onActiveFocusChanged: console.log("A activeFocus", activeFocus)
                onSelectedTextChanged: console.log("A selected [" + selectedText + "]")
            }
            TextField { width: parent.width; placeholderText: "paste here" }
        }
    }
}
