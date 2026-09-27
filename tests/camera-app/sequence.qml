import QtQuick 2.0
import QtMultimedia 5.4

// Camera lifecycle test, driven by itself: back camera, photo, stop/start, front camera, photo,
// back again, unload/reload, photo. One "STEP" line per step (ok or TIMEOUT after 20 s), and a
// "SHOT <name>" line when a screenshot should be taken (seq.sh takes them). Arguments after the
// QML file: "front" starts with the front camera, "gap=MS" unloads the camera MS before a switch,
// "loop=N" runs N rounds of back photo, front camera, front photo, back camera (a stress test),
// step names run only those steps.
Rectangle {
    width: 854; height: 480; color: "black"
    property int step: -1
    property bool leftTarget: false
    property double t0: Date.now()
    function log(s) { console.log(((Date.now() - t0) / 1000).toFixed(1), s) }

    readonly property var args: Qt.application.arguments.slice(2)
    readonly property int gap: parseInt((args.filter(function (a) { return a.indexOf("gap=") === 0 })[0]
                                         || "gap=0").substring(4))
    readonly property var stepArgs: args.filter(function (a) {
        return allSteps.some(function (s) { return s.name === a }) })
    readonly property int loops: parseInt((args.filter(function (a) { return a.indexOf("loop=") === 0 })[0]
                                           || "loop=0").substring(5))
    readonly property var steps: {
        if (loops > 0) {
            var round = allSteps.filter(function (s) {
                return ["back-photo", "front-active", "front-photo", "back-again"].indexOf(s.name) >= 0 })
            var l = [allSteps[0]]
            for (var i = 0; i < loops; ++i) l = l.concat(round)
            return l
        }
        return allSteps.filter(function (s, i) {
            return i === 0 || stepArgs.length === 0 || stepArgs.indexOf(s.name) >= 0 })
    }
    // "wait=MS": switch unloaded, load, wait MS, then start.
    readonly property int wait: parseInt((args.filter(function (a) { return a.indexOf("wait=") === 0 })[0]
                                          || "wait=0").substring(5))
    // "release": stop the camera (Active -> Loaded) before the switch.
    readonly property bool release: args.indexOf("release") >= 0
    function switchTo(position) {
        if (release) {
            camera.stop()
            releaseTimer.position = position
            releaseTimer.start()
            return
        }
        if (wait > 0) {
            camera.cameraState = Camera.UnloadedState
            camera.position = position
            camera.cameraState = Camera.LoadedState
            waitTimer.start()
            return
        }
        if (gap <= 0) { camera.position = position; return }
        camera.cameraState = Camera.UnloadedState
        gapTimer.position = position
        gapTimer.start()
    }
    Timer { id: releaseTimer; property int position; interval: 500
            onTriggered: { camera.position = position; camera.cameraState = Camera.ActiveState } }
    Timer { id: waitTimer; interval: Math.max(wait, 1); onTriggered: camera.cameraState = Camera.ActiveState }
    Timer { id: gapTimer; property int position; interval: Math.max(gap, 1)
            onTriggered: { camera.position = position; camera.cameraState = Camera.ActiveState } }
    readonly property var allSteps: [
        { name: "back-active", status: Camera.ActiveStatus },
        { name: "back-photo", photo: "/home/user/MyDocs/qt5cam-back.jpg" },
        { name: "stop", act: function () { camera.stop() }, status: Camera.LoadedStatus },
        { name: "start", act: function () { camera.start() }, status: Camera.ActiveStatus },
        { name: "front-active", act: function () { switchTo(Camera.FrontFace) },
          status: Camera.ActiveStatus, leave: true },
        { name: "front-photo", photo: "/home/user/MyDocs/qt5cam-front.jpg" },
        { name: "back-again", act: function () { switchTo(Camera.BackFace) },
          status: Camera.ActiveStatus, leave: true },
        { name: "unload", act: function () { camera.cameraState = Camera.UnloadedState },
          status: Camera.UnloadedStatus },
        { name: "reload", act: function () { camera.cameraState = Camera.ActiveState },
          status: Camera.ActiveStatus },
        { name: "back-photo2", photo: "/home/user/MyDocs/qt5cam-back2.jpg" },
        { name: "hires", act: function () {
            var r = camera.imageCapture.supportedResolutions, best = r[0]
            for (var i = 1; i < r.length; ++i)
                if (r[i].width * r[i].height > best.width * best.height) best = r[i]
            log("resolutions " + JSON.stringify(r) + " -> " + best)
            camera.imageCapture.resolution = best
          }, status: Camera.ActiveStatus, leave: true },
        { name: "hires-photo", photo: "/home/user/MyDocs/qt5cam-hires.jpg" }
    ]

    function done(ok) {
        var s = steps[step]
        log("STEP " + step + " " + s.name + (ok ? " ok" : " TIMEOUT") + " status " + camera.cameraStatus)
        if (s.status === Camera.ActiveStatus)
            log("SHOT " + s.name)
        timeout.stop()
        next.start()   // a pause between steps, so the viewfinder shows frames
    }
    function check() {
        var s = steps[step]
        if (s === undefined || s.status === undefined || !timeout.running)
            return
        if (camera.cameraStatus !== s.status)
            leftTarget = true
        else if (leftTarget || !s.leave)
            done(true)
    }
    Timer { id: next; interval: 3000; onTriggered: {
        if (++step >= steps.length) { log("SEQUENCE END"); return }
        var s = steps[step]
        log("begin " + s.name)
        leftTarget = false
        timeout.start()
        if (s.act) s.act()
        if (s.photo) camera.imageCapture.captureToLocation(s.photo)
        check()
    } }
    // One restart after an error, to see whether the camera comes back.
    Timer { id: retry; interval: 1000; onTriggered: { log("retry"); camera.cameraState = Camera.ActiveState } }
    Timer { id: timeout; interval: 20000; onTriggered: done(false) }
    Component.onCompleted: { step = 0; log("begin back-active"); timeout.start(); check() }

    Camera {
        id: camera
        captureMode: Camera.CaptureStillImage
        position: args.indexOf("front") >= 0 ? Camera.FrontFace : Camera.BackFace
        onCameraStatusChanged: { log("camera status " + cameraStatus); check() }
        property bool retried: false
        onErrorChanged: {
            log("camera error " + errorCode + " " + errorString)
            if (errorCode !== Camera.NoError && !retried) { retried = true; retry.start() }
        }
        imageCapture.onImageCaptured: log("captured " + requestId)
        imageCapture.onImageSaved: { log("saved " + path); if (steps[step].photo) done(true) }
        imageCapture.onCaptureFailed: { log("capture failed " + message); if (steps[step].photo) done(false) }
        Component.onCompleted: log("cameras " + JSON.stringify(QtMultimedia.availableCameras))
    }
    VideoOutput { anchors.fill: parent; source: camera; fillMode: VideoOutput.PreserveAspectCrop
                  orientation: camera.orientation }
    Text { color: "white"; font.pixelSize: 20
           text: (step >= 0 && step < steps.length ? steps[step].name : "") + " status " + camera.cameraStatus }
}
