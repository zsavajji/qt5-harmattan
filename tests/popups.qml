// 3.3 check: load each text-editing popup component and print why it fails, if it does.
import QtQuick 2.0
import com.nokia.meego 2.0

Item {
    width: 480; height: 854
    Timer {
        interval: 500; running: true
        onTriggered: {
            var names = ["EditBubble.qml", "Magnifier.qml", "SelectionHandles.qml"]
            for (var i = 0; i < names.length; ++i) {
                var c = Qt.createComponent("file:///home/user/qt5/qml/com/nokia/meego/" + names[i])
                console.log("POPUP", names[i], "status", c.status, c.errorString())
            }
        }
    }
}
