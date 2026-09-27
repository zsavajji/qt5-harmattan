// Lists the visible items that reach the bottom 100 px of the screen (what is the black
// bar under the page?).
import QtQuick 2.0
import com.nokia.meego 2.0

PageStackWindow {
    id: window
    initialPage: Page { Label { text: "bottom items"; anchors.centerIn: parent } }
    function dump(item, depth) {
        if (!item.visible) return
        var p = item.mapToItem(null, 0, 0)
        var q = item.mapToItem(null, item.width, item.height)
        var top = Math.min(p.y, q.y), bottom = Math.max(p.y, q.y)
        var left = Math.min(p.x, q.x), right = Math.max(p.x, q.x)
        if (right > 754 && item.width > 0 && item.height > 0) // landscape X coords: portrait bottom is x near 854
            console.log("BOTTOM", depth, item, item.objectName, "x", Math.round(left), "-", Math.round(right),
                        "y", Math.round(top), "-", Math.round(bottom), item.source !== undefined ? item.source : "",
                        item.color !== undefined ? item.color : "")
        for (var i = 0; i < item.children.length; ++i) dump(item.children[i], depth + 1)
    }
    Timer { interval: 4000; running: true; onTriggered: { console.log("WINDOW", window.width, window.height); dump(window, 0) } }
}
