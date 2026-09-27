// 3.3 check: a half-transparent theme image (the toolbar button background) over grey,
// through the theme provider (left) and from its file (right). Qt 4:
// sed 's/QtQuick 2.0/QtQuick 1.1/' and run with qml4view.
import QtQuick 2.0

Rectangle {
    width: 480; height: 854
    color: "#808080"
    Row {
        y: 100; x: 40; spacing: 40
        BorderImage {
            width: 180; height: 42
            border { left: 15; top: 15; right: 15; bottom: 15 }
            source: "image://theme/meegotouch-button-navigationbar-button-background"
        }
        BorderImage {
            width: 180; height: 42
            border { left: 15; top: 15; right: 15; bottom: 15 }
            source: "/usr/share/themes/blanco/meegotouch/images/theme/basement/meegotouch-navigationbar-update/meegotouch-button-navigationbar-button-background.png"
        }
    }
}
