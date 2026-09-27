// 3.3 check: copy, paste, (the edit bubble clears the clipboard after a paste, as in Qt 4),
// copy again, paste again. Each paste goes into field B; the log shows B's text.
import QtQuick 2.0
import com.nokia.meego 2.0

PageStackWindow {
    initialPage: Page {
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 20
            TextField { id: a; width: parent.width; text: "first second" }
            TextField { id: b; width: parent.width; text: "" }
        }
        Timer {
            interval: 2000; repeat: true; running: true
            property int step: 0
            onTriggered: {
                switch (step++) {
                case 0: a.select(0, 5); a.copy(); console.log(Date.now() % 1000000 / 1000, "CLIP copied first"); break
                case 1: b.paste(); console.log(Date.now() % 1000000 / 1000, "CLIP pasted, B = [" + b.text + "]"); break
                case 2: inputContext.clearClipboard(); console.log(Date.now() % 1000000 / 1000, "CLIP cleared"); break
                case 3: a.select(6, 12); a.copy(); console.log(Date.now() % 1000000 / 1000, "CLIP copied second"); break
                case 4: b.paste(); console.log(Date.now() % 1000000 / 1000, "CLIP pasted, B = [" + b.text + "]"); break
                default: running = false; Qt.quit()
                }
            }
        }
    }
}
