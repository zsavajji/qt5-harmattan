// 3.5 check: startup time of a typical com.nokia.meego page. Run with
// QT_MESSAGE_PATTERN="%{time process} %{message}": the STARTUP line gives seconds since the
// process started, when the page is built.
import QtQuick 2.0
import com.nokia.meego 2.0

PageStackWindow {
    initialPage: Page {
        tools: ToolBarLayout {
            ToolIcon { iconId: "toolbar-back" }
            ToolIcon { iconId: "toolbar-view-menu" }
        }
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 16
            Label { text: "Startup test" }
            TextField { width: parent.width; placeholderText: "Text field" }
            Button { text: "Button" }
            Row { spacing: 20; CheckBox { text: "Check" } Switch {} }
            Slider { width: parent.width }
            ButtonRow { Button { text: "One" } Button { text: "Two" } }
        }
        Component.onCompleted: console.log("STARTUP page built")
    }
}
