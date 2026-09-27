// 3.3 check: MaskedItem (ProgressBar's fill) shows its child only where the mask is.
// Expected: a red bar 240 px wide on grey, not 400.
import QtQuick 2.0
import "file:///opt/qt5/qml/com/nokia/meego"

Rectangle {
    width: 480; height: 854
    color: "grey"
    MaskedItem {
        id: m
        x: 20; y: 100; width: 400; height: 40
        mask: Rectangle { width: 240; height: 40; color: "black" }
        Rectangle { width: 400; height: 40; color: "red" }
        Component.onCompleted: console.log("masked", width, height, targetItem.sourceRect, maskItem.sourceRect)
    }
}
