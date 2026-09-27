// Phase 4 check: video through QtMultimedia's GStreamer 0.10 backend into a VideoOutput.
import QtQuick 2.0
import QtMultimedia 5.0

Rectangle {
    width: 854; height: 480; color: "black"
    MediaPlayer {
        id: player
        source: "file:///home/user/MyDocs/Movies/Nokia Pure.mp4"
        autoPlay: true
        onStatusChanged: console.log(Date.now() % 100000, "status", status, "duration", duration)
        onPlaybackStateChanged: console.log(Date.now() % 100000, "state", playbackState)
        onError: console.log("ERROR", error, errorString)
    }
    VideoOutput { anchors.fill: parent; source: player }
    Text { color: "white"; font.pixelSize: 24; text: player.position + " / " + player.duration }
}
