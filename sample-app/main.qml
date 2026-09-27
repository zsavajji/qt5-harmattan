import QtQuick 2.0
import com.nokia.meego 2.0

PageStackWindow {
    initialPage: Page {
        tools: ToolBarLayout {
            ToolIcon { iconId: "toolbar-view-menu"; anchors.right: parent.right; onClicked: menu.open() }
        }
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 16
            Label { text: "Qt 5 on Harmattan"; font.pixelSize: 32 }
            TextField { width: parent.width; placeholderText: "Type here" }
            Button { text: "Say hello"; onClicked: banner.show() }
            Row { spacing: 16; Switch { id: dark } Label { text: "Inverted theme"; anchors.verticalCenter: parent.verticalCenter } }
        }
        Binding { target: theme; property: "inverted"; value: dark.checked }
        InfoBanner { id: banner; text: "Hello from Qt " + Qt.application.version }
        Menu {
            id: menu
            MenuLayout { MenuItem { text: "Quit"; onClicked: Qt.quit() } }
        }
    }
}
