// Phase 4 check: audio through QtMultimedia's GStreamer 0.10 backend (playbin2, pulsesink).
import QtQuick 2.0
import QtMultimedia 5.0

Rectangle {
    width: 480; height: 854; color: "black"
    MediaPlayer {
        id: player
        source: "file:///usr/share/sounds/ring-tones/Arcade.mp3"
        autoPlay: true
        onStatusChanged: console.log(Date.now() % 100000, "status", status, "duration", duration)
        onPlaybackStateChanged: console.log(Date.now() % 100000, "state", playbackState, "position", position)
        onError: console.log("ERROR", error, errorString)
    }
    Text { color: "white"; font.pixelSize: 32; anchors.centerIn: parent; text: player.position + " / " + player.duration }
}
