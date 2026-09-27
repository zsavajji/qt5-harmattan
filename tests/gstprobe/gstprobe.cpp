// A QML plugin for GStreamer experiments inside an app that has the Aegis credentials (e.g.
// qt5-cameratest with GRP::video): GstProbe.run(description, ms) builds the pipeline, plays it
// for ms milliseconds in a worker thread and logs every step, the bus messages and the number
// of buffers reaching the sink named "out" (a fakesink). Descriptions are gst-launch syntax, or
// "camerabin2 <camera-source> <video-source> && prop=caps && ..." for camerabin2 with elements as
// properties and caps properties set.
#include <QtQml/QQmlExtensionPlugin>
#include <QtQml/qqml.h>
#include <QtCore/QThread>
#include <gst/gst.h>
#include <gst/pbutils/encoding-profile.h>

static int buffers;
static void onHandoff(GstElement *, GstBuffer *, GstPad *, gpointer) { ++buffers; }
static int srcBuffers;
static gboolean onSrcBuffer(GstPad *, GstBuffer *, gpointer) { ++srcBuffers; return TRUE; }
static GstElement *cameraSource;

static void setCaps(GstElement *cb, const QByteArray &d);

static GstElement *build(const QByteArray &d)
{
    GError *err = nullptr;
    if (!d.startsWith("camerabin2 ")) {
        GstElement *p = gst_parse_launch(d.constData(), &err);
        if (err) { qWarning("PROBE parse error: %s", err->message); g_error_free(err); }
        return p;
    }
    const QList<QByteArray> a = d.split(' ');
    GstElement *cb = gst_element_factory_make("camerabin2", nullptr);
    GstElement *src = gst_element_factory_make(a.value(1).constData(), nullptr);
    GstElement *vsrc = a.value(2) == "-" ? nullptr : gst_element_factory_make(a.value(2).constData(), nullptr);
    GstElement *sink = gst_element_factory_make("fakesink", "out");
    qWarning("PROBE camerabin2 %p src %p vsrc %p", cb, src, vsrc);
    cameraSource = src;
    if (!cb || !src)
        return nullptr;
    if (vsrc)
        g_object_set(src, "video-source", vsrc, nullptr);
    g_object_set(cb, "camera-source", src, "viewfinder-sink", sink, nullptr);
    // camerabin2 needs an encodable video profile to reach READY: MP4, H.264 (DSP), AAC.
    GstCaps *cc = gst_caps_from_string("video/quicktime, variant=(string)iso");
    GstEncodingContainerProfile *prof = gst_encoding_container_profile_new("mp4", nullptr, cc, nullptr);
    GstCaps *vc = gst_caps_from_string("video/x-h264"), *ac = gst_caps_from_string("audio/mpeg, mpegversion=(int)4");
    gst_encoding_container_profile_add_profile(prof, (GstEncodingProfile *)gst_encoding_video_profile_new(vc, nullptr, nullptr, 0));
    gst_encoding_container_profile_add_profile(prof, (GstEncodingProfile *)gst_encoding_audio_profile_new(ac, nullptr, nullptr, 0));
    gst_caps_unref(cc); gst_caps_unref(vc); gst_caps_unref(ac);
    g_object_set(cb, "video-profile", prof, nullptr);
    gst_encoding_profile_unref(prof);
    if (d.contains("@previews")) // Qt's image capture: previews posted to the bus
        g_object_set(cb, "post-previews", TRUE, nullptr);
    if (d.contains("@jpeg")) { // Qt's image profile: JPEG
        GstCaps *jc = gst_caps_from_string("image/jpeg");
        GstEncodingVideoProfile *ip = gst_encoding_video_profile_new(jc, nullptr, nullptr, 1);
        gst_encoding_video_profile_set_variableframerate(ip, TRUE);
        g_object_set(cb, "image-profile", ip, nullptr);
        gst_encoding_profile_unref(ip); gst_caps_unref(jc);
        qWarning("PROBE image-profile image/jpeg");
    }
    if (!d.contains("@late"))
        setCaps(cb, d);
    return cb;
}

// " && property=caps" parts, e.g. "&& viewfinder-caps=video/x-raw-yuv, width=(int)848"; with
// "@late" they are set once the pipeline is READY, as Qt does in start().
static void setCaps(GstElement *cb, const QByteArray &d)
{
    const QList<QByteArray> parts = d.split('&');
    for (const QByteArray &part : parts) {
        const QByteArray kv = part.trimmed();
        const int eq = kv.indexOf('=');
        if (eq < 0 || kv.startsWith("camerabin2") || kv.startsWith("@"))
            continue;
        const QByteArray key = kv.left(eq), value = kv.mid(eq + 1);
        GstCaps *caps = gst_caps_from_string(value.constData());
        qWarning("PROBE %s = %s (%s)", key.constData(), value.constData(), caps ? "ok" : "bad caps");
        if (caps) { g_object_set(cb, key.constData(), caps, nullptr); gst_caps_unref(caps); }
    }
}

static const char *qt_expFactory(GstElement *e) { GstElementFactory *f = gst_element_get_factory(e); return f ? GST_PLUGIN_FEATURE_NAME(f) : "?"; }
static void expDumpProps(const char *tag, GstElement *e) // EXPERIMENT
{
    if (!e) return;
    guint n; GParamSpec **ps = g_object_class_list_properties(G_OBJECT_GET_CLASS(e), &n);
    for (guint i = 0; i < n; ++i) {
        if (!(ps[i]->flags & G_PARAM_READABLE)) continue;
        GValue v = { 0, { { 0 } } }; g_value_init(&v, ps[i]->value_type);
        g_object_get_property(G_OBJECT(e), ps[i]->name, &v);
        gchar *t;
        if (G_VALUE_HOLDS_OBJECT(&v)) { GObject *o = static_cast<GObject *>(g_value_get_object(&v)); t = g_strdup(o && GST_IS_ELEMENT(o) ? qt_expFactory(GST_ELEMENT(o)) : o ? "obj" : "null"); }
        else t = g_strdup_value_contents(&v);
        qWarning("DUMP %s %s.%s = %s", tag, qt_expFactory(e), ps[i]->name, t);
        g_free(t); g_value_unset(&v);
    }
    g_free(ps);
    if (GST_IS_BIN(e)) {
        GstIterator *it = gst_bin_iterate_elements(GST_BIN(e)); gpointer c;
        while (gst_iterator_next(it, &c) == GST_ITERATOR_OK) { qWarning("DUMP %s %s child %s (%s)", tag, qt_expFactory(e), GST_OBJECT_NAME(c), qt_expFactory(GST_ELEMENT(c))); gst_object_unref(c); }
        gst_iterator_free(it);
    }
}

static void logBus(GstElement *p)
{
    GstBus *bus = gst_element_get_bus(p);
    while (GstMessage *m = gst_bus_pop(bus)) {
        const GstMessageType t = GST_MESSAGE_TYPE(m);
        if (t == GST_MESSAGE_ERROR || t == GST_MESSAGE_WARNING) {
            GError *e = nullptr; gchar *dbg = nullptr;
            if (t == GST_MESSAGE_ERROR) gst_message_parse_error(m, &e, &dbg); else gst_message_parse_warning(m, &e, &dbg);
            qWarning("PROBE %s from %s: %s | %s", GST_MESSAGE_TYPE_NAME(m), GST_OBJECT_NAME(GST_MESSAGE_SRC(m)),
                     e ? e->message : "", dbg ? dbg : "");
            if (e) g_error_free(e);
            g_free(dbg);
        } else if (t == GST_MESSAGE_STATE_CHANGED && GST_MESSAGE_SRC(m) == GST_OBJECT(p)) {
            GstState o, n, pe; gst_message_parse_state_changed(m, &o, &n, &pe);
            qWarning("PROBE pipeline %s -> %s", gst_element_state_get_name(o), gst_element_state_get_name(n));
        }
        gst_message_unref(m);
    }
    gst_object_unref(bus);
}

class Worker : public QThread
{
public:
    Worker(const QByteArray &d, int ms) : m_d(d), m_ms(ms) {}
    void run() override
    {
        qWarning("PROBE start: %s", m_d.constData());
        GstElement *p = build(m_d);
        if (!p) { qWarning("PROBE no pipeline"); return; }
        if (GstElement *out = GST_IS_BIN(p) ? gst_bin_get_by_name(GST_BIN(p), "out") : nullptr) {
            g_object_set(out, "signal-handoffs", TRUE, "sync", FALSE, nullptr);
            g_signal_connect(out, "handoff", G_CALLBACK(onHandoff), nullptr);
            gst_object_unref(out);
            qWarning("PROBE counting at sink \"out\"");
        }
        srcBuffers = 0;
        if (m_d.startsWith("camerabin2 ") && cameraSource) {
            GstPad *vf = gst_element_get_static_pad(cameraSource, "vfsrc");
            qWarning("PROBE vfsrc pad %p", vf);
            if (vf) { gst_pad_add_buffer_probe(vf, G_CALLBACK(onSrcBuffer), nullptr); gst_object_unref(vf); }
        }
        buffers = 0;
        // "@direct": READY, then straight to PLAYING, as Qt does
        // "@cycle": READY, NULL, READY, PLAYING, as Qt's reloads do
        // "@restart": PLAYING, back to NULL and PLAYING again, as Qt's reload once the
        // viewfinder surface arrives
        const QList<GstState> steps = m_d.contains("@restart")
                ? QList<GstState>{ GST_STATE_READY, GST_STATE_PLAYING, GST_STATE_NULL, GST_STATE_READY, GST_STATE_PLAYING }
                : m_d.contains("@cycle")
                ? QList<GstState>{ GST_STATE_READY, GST_STATE_NULL, GST_STATE_READY, GST_STATE_PLAYING }
                : m_d.contains("@direct")
                ? QList<GstState>{ GST_STATE_READY, GST_STATE_PLAYING }
                : QList<GstState>{ GST_STATE_READY, GST_STATE_PAUSED, GST_STATE_PLAYING };
        for (GstState s : steps) {
            if (s == GST_STATE_PLAYING && m_d.contains("@dump")) { expDumpProps("probe", p); expDumpProps("probe", cameraSource);
                GstElement *vs = nullptr; if (cameraSource) g_object_get(cameraSource, "video-source", &vs, nullptr); expDumpProps("probe", vs); if (vs) gst_object_unref(vs); }
            qWarning("PROBE set %s", gst_element_state_get_name(s));
            GstStateChangeReturn r = gst_element_set_state(p, s);
            GstState cur = GST_STATE_VOID_PENDING, pend = GST_STATE_VOID_PENDING;
            if (r == GST_STATE_CHANGE_ASYNC)
                r = gst_element_get_state(p, &cur, &pend, 5 * GST_SECOND);
            qWarning("PROBE set %s -> %s", gst_element_state_get_name(s), gst_element_state_change_return_get_name(r));
            logBus(p);
            if (r == GST_STATE_CHANGE_FAILURE)
                break;
            if (s == GST_STATE_READY && m_d.contains("@late"))
                setCaps(p, m_d);
        }
        msleep(m_ms);
        logBus(p);
        qWarning("PROBE buffers %d at sink, %d at vfsrc", buffers, srcBuffers);
        gst_element_set_state(p, GST_STATE_NULL);
        gst_object_unref(p);
        qWarning("PROBE done");
    }

private:
    QByteArray m_d;
    int m_ms;
};

class GstProbe : public QObject
{
    Q_OBJECT
public:
    // Runs one description after another, each in its own thread (a hang stays in the log).
    // The same on the calling (GUI) thread: a hang freezes the app, the log shows where.
    Q_INVOKABLE void runHere(const QString &description, int ms)
    {
        gst_init(nullptr, nullptr);
        Worker job(description.toUtf8(), ms);
        job.run();
    }

    Q_INVOKABLE void run(const QStringList &descriptions, int ms)
    {
        gst_init(nullptr, nullptr);
        auto *w = new QThread; // sequencer
        QObject::connect(w, &QThread::started, [descriptions, ms] {
            for (const QString &d : descriptions) {
                Worker job(d.toUtf8(), ms);
                job.start();
                if (!job.wait(ms + 20000)) { qWarning("PROBE HUNG: %s", qPrintable(d)); return; }
            }
            qWarning("PROBE all done");
        });
        w->start();
    }
};

class GstProbePlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterSingletonType<GstProbe>(uri, 1, 0, "GstProbe", [](QQmlEngine *, QJSEngine *) -> QObject * { return new GstProbe; });
    }
};

#include "gstprobe.moc"
