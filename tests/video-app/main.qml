import QtQuick 2.0
import QtMultimedia 5.0

Rectangle {
    width: 854; height: 480; color: "black"
    MediaPlayer {
        id: player
        source: "file:///home/user/MyDocs/Movies/Nokia Pure.mp4"
        autoPlay: true
    }
    VideoOutput { anchors.fill: parent; source: player }
    MouseArea {
        anchors.fill: parent
        onClicked: player.playbackState == MediaPlayer.PlayingState ? player.pause() : player.play()
    }
    Text {
        color: "white"; font.pixelSize: 24
        text: Math.round(player.position / 1000) + " / " + Math.round(player.duration / 1000) + " s"
    }
}
