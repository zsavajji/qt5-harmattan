// 3.3 "done when": the same page under the stock Qt 4 components and the Qt 5 port.
// Qt 4: sed 's/QtQuick 2.0/QtQuick 1.1/; s/meego 2.0/meego 1.0/' and run with qml4view.
import QtQuick 2.0
import com.nokia.meego 2.0

PageStackWindow {
    initialPage: Page {
        orientationLock: PageOrientation.LockPortrait
        tools: ToolBarLayout {
            ToolIcon { iconId: "toolbar-back" }
            ToolButton { text: "Save" }
            ToolIcon { iconId: "toolbar-view-menu" }
        }
        Column {
            anchors { fill: parent; margins: 16 }
            spacing: 16
            Label { text: "Components"; font.pixelSize: 32 }
            Button { text: "Button" }
            Button { text: "Checked"; checkable: true; checked: true }
            ButtonRow {
                Button { text: "One" }
                Button { text: "Two" }
                Button { text: "Three" }
            }
            TextField { width: parent.width; placeholderText: "Placeholder" }
            TextField { width: parent.width; text: "Some text" }
            Row {
                spacing: 32
                CheckBox { text: "Check"; checked: true }
                Switch { checked: true }
                RadioButton { text: "Radio"; checked: true }
            }
            Slider { width: parent.width; value: 0.4 }
            ProgressBar { width: parent.width; value: 0.6 }
        }
    }
}
