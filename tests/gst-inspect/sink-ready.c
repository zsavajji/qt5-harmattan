/* Phase 4 check: can Nokia's gltexturesink go to READY in video-texture mode, with the X and
 * EGL displays from the same Xlib connection ("same") or from two ("split", as Qt 5's EGL has
 * its own)? Prints the state change result and the bus errors. Usage: sink-ready same|split [nograb [nofb]] */
#include <gst/gst.h>
#include <EGL/egl.h>
#include <X11/Xlib.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    gst_init(&argc, &argv);
    int split = argc > 1 && !strcmp(argv[1], "split");
    Display *x = XOpenDisplay(NULL), *ex = split ? XOpenDisplay(NULL) : x;
    EGLDisplay d = eglGetDisplay((EGLNativeDisplayType)ex);
    eglInitialize(d, NULL, NULL);
    EGLint attrs[] = { EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_NONE };
    EGLConfig config; EGLint n = 0;
    eglChooseConfig(d, attrs, &config, 1, &n);
    EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
    EGLContext c = eglCreateContext(d, config, EGL_NO_CONTEXT, ctxAttrs);
    EGLint pb[] = { EGL_WIDTH, 16, EGL_HEIGHT, 16, EGL_NONE };
    EGLSurface s = eglCreatePbufferSurface(d, config, pb);
    printf("%s: configs %d, context %p, current %d\n", split ? "split" : "same", n, c, eglMakeCurrent(d, s, s, c));

    GstElement *sink = gst_element_factory_make("gltexturesink", NULL);
    g_object_set(sink, "x-display", x, "egl-display", d, "egl-context", c, "render-mode", "video-texture", "dont-grab-xv-port", argc > 2, "use-framebuffer-memory", argc > 3 ? FALSE : TRUE, NULL);
    GstBus *bus = gst_bus_new();
    gst_element_set_bus(sink, bus);
    GstStateChangeReturn r = gst_element_set_state(sink, GST_STATE_READY);
    printf("READY: %s\n", gst_element_state_change_return_get_name(r));
    GstMessage *m;
    while ((m = gst_bus_pop(bus))) {
        if (GST_MESSAGE_TYPE(m) == GST_MESSAGE_ERROR || GST_MESSAGE_TYPE(m) == GST_MESSAGE_WARNING) {
            GError *e = NULL; gchar *dbg = NULL;
            if (GST_MESSAGE_TYPE(m) == GST_MESSAGE_ERROR) gst_message_parse_error(m, &e, &dbg);
            else gst_message_parse_warning(m, &e, &dbg);
            printf("%s: %s (%s)\n", GST_MESSAGE_TYPE_NAME(m), e->message, dbg ? dbg : "");
        }
        gst_message_unref(m);
    }
    gst_element_set_state(sink, GST_STATE_NULL);
    return 0;
}
