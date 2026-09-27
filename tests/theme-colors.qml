// 3.3 check: does changing theme.colorScheme recolour the components? Cycles the scheme
// every 2 s and logs the resulting image URL. Run: qmlscene theme-colors.qml
import QtQuick 2.0
import com.nokia.meego 2.0

PageStackWindow {
    initialPage: Page {
        Column {
            anchors.centerIn: parent
            spacing: 30
            Button { id: button; text: "Checked button"; checkable: true; checked: true }
            Switch { checked: true }
            Label { id: label; text: "scheme " + theme.colorScheme }
        }
    }
    Timer {
        property int scheme: 1
        interval: 2000; running: true; repeat: true
        onTriggered: {
            scheme = scheme === 7 ? 13 : 7
            theme.colorScheme = scheme
            console.log("scheme", theme.colorScheme, "colorString", theme.colorString,
                        "checkedBackground", button.platformStyle.checkedBackground)
        }
    }
}
