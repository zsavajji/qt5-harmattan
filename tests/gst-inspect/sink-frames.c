/* Phase 4 check: does gltexturesink (video-texture mode, no framebuffer memory) emit frame-ready
 * when playing a file through playbin2, and can the frames be acquired and bound in our own EGL
 * context? Usage: sink-frames file.mp4 [egl|noegl] [fb|nofb] [seconds]   (default 5 s; fb:
 * framebuffer memory,
 * /dev/fb2 is root:video) */
#include <gst/gst.h>
#include <gst/interfaces/xoverlay.h>
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <X11/Xlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern gboolean meego_gst_video_texture_acquire_frame(void *sink, gint frame);
extern gboolean meego_gst_video_texture_bind_frame(void *sink, gint target, gint frame);
extern void meego_gst_video_texture_release_frame(void *sink, gint frame, gpointer sync);

static GstElement *sink;
static Window window;
static volatile int frames, lastFrame = -1;

static void frameReady(GstElement *s, gint frame, gpointer data)
{
    (void)s; (void)data;
    if (frames++ < 3)
        printf("frame-ready %d\n", frame);
    lastFrame = frame;
}

static gboolean tick(gpointer data)
{
    (void)data;
    int frame = lastFrame;
    if (frame >= 0 && eglGetCurrentContext() != EGL_NO_CONTEXT) {
        static int shown;
        GLuint tex;
        glGenTextures(1, &tex);
        glBindTexture(0x8D65, tex);   /* GL_TEXTURE_EXTERNAL_OES */
        int a = meego_gst_video_texture_acquire_frame(sink, frame);
        int b = a ? meego_gst_video_texture_bind_frame(sink, 0x8D65, frame) : -1;
        if (shown++ < 3)
            printf("frame %d: acquire %d bind %d gl 0x%x\n", frame, a, b, glGetError());
        if (a) {
            meego_gst_video_texture_bind_frame(sink, 0x8D65, -1);
            meego_gst_video_texture_release_frame(sink, frame, NULL);
        }
        glDeleteTextures(1, &tex);
    }
    return TRUE;
}

// As Qt Mobility: the sink asks for a window (prepare-xwindow-id), even in video-texture mode.
static GstBusSyncReply syncHandler(GstBus *bus, GstMessage *m, gpointer data)
{
    (void)bus; (void)data;
    if (GST_MESSAGE_TYPE(m) == GST_MESSAGE_ELEMENT && m->structure
            && gst_structure_has_name(m->structure, "prepare-xwindow-id")) {
        printf("prepare-xwindow-id: window 0x%lx\n", window);
        gst_x_overlay_set_xwindow_id(GST_X_OVERLAY(GST_MESSAGE_SRC(m)), window);
    }
    return GST_BUS_PASS;
}

static gboolean quit(gpointer loop) { g_main_loop_quit(loop); return FALSE; }

int main(int argc, char **argv)
{
    gst_init(&argc, &argv);
    Display *x = XOpenDisplay(NULL);
    EGLDisplay d = eglGetDisplay((EGLNativeDisplayType)x);
    EGLContext c = EGL_NO_CONTEXT;
    eglInitialize(d, NULL, NULL);
    if (argc > 2 && !strcmp(argv[2], "egl")) {
        EGLint attrs[] = { EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_NONE };
        EGLConfig config; EGLint n = 0;
        eglChooseConfig(d, attrs, &config, 1, &n);
        Window w = XCreateSimpleWindow(x, DefaultRootWindow(x), 0, 0, 64, 64, 0, 0, 0);
        window = w;
        EGLSurface s = eglCreateWindowSurface(d, config, (EGLNativeWindowType)w, NULL);
        EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
        c = eglCreateContext(d, config, EGL_NO_CONTEXT, ctxAttrs);
        printf("egl: configs %d, surface %p, context %p, current %d\n", n, s, c, eglMakeCurrent(d, s, s, c));
    }
    sink = gst_element_factory_make("gltexturesink", NULL);
    g_object_set(sink, "x-display", x, "egl-display", d, "egl-context", c, "render-mode", "video-texture",
                 "use-framebuffer-memory", argc > 3 && !strcmp(argv[3], "fb"), NULL);
    g_signal_connect(sink, "frame-ready", G_CALLBACK(frameReady), NULL);
    GstElement *play = gst_element_factory_make("playbin2", NULL);
    gchar *uri = g_filename_to_uri(argv[1], NULL, NULL);
    g_object_set(play, "uri", uri, "video-sink", sink, NULL);
    // playbin2 native-video (0x40): no colorspace converter or scaler in front of the sink, so
    // the decoder writes into the sink's own buffers (as Nokia's StreamingSink sets "flags").
    if (getenv("PLAY_FLAGS")) {
        g_object_set(play, "flags", (gint)strtol(getenv("PLAY_FLAGS"), NULL, 0), NULL);
        gint flags; g_object_get(play, "flags", &flags, NULL);
        printf("playbin2 flags 0x%x\n", flags);
    }
    gst_bus_set_sync_handler(gst_element_get_bus(play), syncHandler, NULL);
    printf("PLAYING: %s\n", gst_element_state_change_return_get_name(gst_element_set_state(play, GST_STATE_PLAYING)));
    GMainLoop *loop = g_main_loop_new(NULL, FALSE);
    g_timeout_add(30, tick, NULL);
    const int seconds = argc > 4 ? atoi(argv[4]) : 5;
    g_timeout_add(seconds * 1000, quit, loop);
    g_main_loop_run(loop);
    GstMessage *m;
    GstBus *bus = gst_element_get_bus(play);
    while ((m = gst_bus_pop(bus))) {
        GstMessageType t = GST_MESSAGE_TYPE(m);
        if (t == GST_MESSAGE_ERROR || t == GST_MESSAGE_WARNING) {
            GError *e = NULL; gchar *dbg = NULL;
            if (t == GST_MESSAGE_ERROR) gst_message_parse_error(m, &e, &dbg);
            else gst_message_parse_warning(m, &e, &dbg);
            printf("%s from %s: %s (%s)\n", GST_MESSAGE_TYPE_NAME(m), GST_OBJECT_NAME(m->src), e->message, dbg ? dbg : "");
        } else if (t == GST_MESSAGE_STATE_CHANGED && (m->src == GST_OBJECT(sink) || m->src == GST_OBJECT(play))) {
            GstState o, n; gst_message_parse_state_changed(m, &o, &n, NULL);
            printf("state %s: %s -> %s\n", GST_OBJECT_NAME(m->src), gst_element_state_get_name(o), gst_element_state_get_name(n));
        } else if (t != GST_MESSAGE_STATE_CHANGED && t != GST_MESSAGE_TAG && t != GST_MESSAGE_DURATION) {
            printf("message %s from %s\n", GST_MESSAGE_TYPE_NAME(m), GST_OBJECT_NAME(m->src));
        }
        gst_message_unref(m);
    }
    GstState cur, pend;
    gst_element_get_state(play, &cur, &pend, 0);
    GstBuffer *last = NULL;
    g_object_get(sink, "last-buffer", &last, NULL);
    GstPad *pad = gst_element_get_static_pad(sink, "sink");
    GstCaps *caps = gst_pad_get_negotiated_caps(pad);
    gchar *capsText = caps ? gst_caps_to_string(caps) : g_strdup("none");
    printf("pipeline %s (pending %s), sink last buffer %p, caps %s\n", gst_element_state_get_name(cur),
           gst_element_state_get_name(pend), last, capsText);
    printf("frames in %d s: %d\n", seconds, frames);
    gst_element_set_state(play, GST_STATE_NULL);
    return 0;
}
