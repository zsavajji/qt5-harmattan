import QtQuick 2.0
import QtMultimedia 5.0

// Playback check, driven by itself (run with qt5-cameratest-dev for the dev tree and GRP::video):
// play 8 s, pause 2 s, play 4 s, stop, play 4 s. Logs the position every second, then "END".
Rectangle {
    width: 854; height: 480; color: "black"
    property int t: 0
    MediaPlayer {
        id: player
        source: "file:///home/user/MyDocs/Movies/Nokia Pure.mp4"
        autoPlay: true
        onErrorChanged: console.log("error", error, errorString)
        onPlaybackStateChanged: console.log("state", playbackState)
    }
    VideoOutput { anchors.fill: parent; source: player }
    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: {
            ++t
            console.log("t", t, "position", player.position, "state", player.playbackState)
            if (t === 8) player.pause()
            else if (t === 10) player.play()
            else if (t === 14) player.stop()
            else if (t === 15) player.play()
            else if (t === 19) { console.log("END"); Qt.quit() }
        }
    }
}
