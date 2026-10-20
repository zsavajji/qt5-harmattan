import QtQuick 2.0
import QtDocGallery 5.0

// QtDocGallery over the phone's Tracker (patches/qtdocgallery): every image, newest first.
// Logs the count when the query finishes and shows the first images. Run with the
// TrackerReadAccess credential, or from ssh on an open-mode phone.
Rectangle {
    width: 854; height: 480; color: "black"
    GridView {
        anchors.fill: parent
        cellWidth: 160; cellHeight: 160
        model: DocumentGalleryModel {
            id: images
            rootType: DocumentGallery.Image
            properties: ["url"]
            sortProperties: ["-lastModified"]
            autoUpdate: false
            onStatusChanged: console.log("status", status, "count", count)
        }
        delegate: Image {
            width: 156; height: 156
            sourceSize { width: 156; height: 156 }
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: url
        }
    }
    Text { color: "white"; font.pixelSize: 28; text: "status " + images.status + " count " + images.count }
}
