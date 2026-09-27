/* Phase 4 check: draws gltexturesink's frames full screen the way Qt Mobility did, per frame:
 * acquire, bind to a GL_TEXTURE_EXTERNAL_OES texture, draw, swap, unbind, fence, release.
 * Needs /dev/fb2 access (framebuffer memory). Usage: sink-draw file.mp4 [seconds]
 * Prints how many frames were drawn: the pipeline must keep going and the picture be visible. */
#include <gst/gst.h>
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <stdlib.h>

extern gboolean meego_gst_video_texture_acquire_frame(void *sink, gint frame);
extern gboolean meego_gst_video_texture_bind_frame(void *sink, gint target, gint frame);
extern void meego_gst_video_texture_release_frame(void *sink, gint frame, gpointer sync);

#define GL_TEXTURE_EXTERNAL_OES 0x8D65
#define EGL_SYNC_FENCE_KHR 0x30F9
typedef void *(*CreateSync)(EGLDisplay, EGLenum, const EGLint *);

static GstElement *sink;
static volatile gint pending = -1;
static int received;

static void frameReady(GstElement *s, gint frame, gpointer data)
{
    (void)s; (void)data;
    g_atomic_int_set(&pending, frame);
    received++;
}

static GLuint shader(GLenum type, const char *src)
{
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, NULL);
    glCompileShader(s);
    GLint ok; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) { char log[512]; glGetShaderInfoLog(s, sizeof log, NULL, log); printf("shader: %s\n", log); }
    return s;
}

int main(int argc, char **argv)
{
    gst_init(&argc, &argv);
    int seconds = argc > 2 ? atoi(argv[2]) : 10;
    Display *x = XOpenDisplay(NULL);
    int w = 854, h = 480;
    Window win = XCreateSimpleWindow(x, DefaultRootWindow(x), 0, 0, w, h, 0, 0, 0);
    Atom state = XInternAtom(x, "_NET_WM_STATE", False), full = XInternAtom(x, "_NET_WM_STATE_FULLSCREEN", False);
    XChangeProperty(x, win, state, XA_ATOM, 32, PropModeReplace, (unsigned char *)&full, 1);
    XMapWindow(x, win);
    XFlush(x);

    EGLDisplay d = eglGetDisplay((EGLNativeDisplayType)x);
    eglInitialize(d, NULL, NULL);
    EGLint attrs[] = { EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_NONE };
    EGLConfig config; EGLint n = 0;
    eglChooseConfig(d, attrs, &config, 1, &n);
    EGLSurface surf = eglCreateWindowSurface(d, config, (EGLNativeWindowType)win, NULL);
    EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
    EGLContext c = eglCreateContext(d, config, EGL_NO_CONTEXT, ctxAttrs);
    eglMakeCurrent(d, surf, surf, c);
    CreateSync createSync = (CreateSync)eglGetProcAddress("eglCreateSyncKHR");

    GLuint prog = glCreateProgram();
    glAttachShader(prog, shader(GL_VERTEX_SHADER,
        "attribute vec2 pos; varying vec2 tc; void main() { tc = vec2(pos.x * 0.5 + 0.5, 0.5 - pos.y * 0.5); gl_Position = vec4(pos, 0.0, 1.0); }"));
    glAttachShader(prog, shader(GL_FRAGMENT_SHADER,
        "#extension GL_OES_EGL_image_external : require\n"
        "uniform samplerExternalOES tex; varying highp vec2 tc; void main() { gl_FragColor = texture2D(tex, tc); }"));
    glBindAttribLocation(prog, 0, "pos");
    glLinkProgram(prog);
    glUseProgram(prog);
    static const GLfloat quad[] = { -1, -1, 1, -1, -1, 1, 1, 1 };
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, quad);
    glEnableVertexAttribArray(0);
    GLuint tex; glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, tex);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    sink = gst_element_factory_make("gltexturesink", NULL);
    g_object_set(sink, "x-display", x, "egl-display", d, "egl-context", c, "render-mode", "video-texture",
                 "use-framebuffer-memory", TRUE, NULL);
    g_signal_connect(sink, "frame-ready", G_CALLBACK(frameReady), NULL);
    GstElement *play = gst_element_factory_make("playbin2", NULL);
    g_object_set(play, "uri", g_filename_to_uri(argv[1], NULL, NULL), "video-sink", sink, "flags", 0x57, NULL);
    gst_element_set_state(play, GST_STATE_PLAYING);

    int drawn = 0, failed = 0;
    gint64 end = g_get_monotonic_time() + seconds * G_USEC_PER_SEC;
    while (g_get_monotonic_time() < end) {
        gint frame = g_atomic_int_get(&pending);
        if (frame < 0 || !g_atomic_int_compare_and_exchange(&pending, frame, -1)) {
            g_usleep(2000);
            continue;
        }
        glBindTexture(GL_TEXTURE_EXTERNAL_OES, tex);
        if (!meego_gst_video_texture_acquire_frame(sink, frame) ||
                !meego_gst_video_texture_bind_frame(sink, GL_TEXTURE_EXTERNAL_OES, frame)) {
            failed++;
            continue;
        }
        glClear(GL_COLOR_BUFFER_BIT);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        eglSwapBuffers(d, surf);
        meego_gst_video_texture_bind_frame(sink, GL_TEXTURE_EXTERNAL_OES, -1);
        meego_gst_video_texture_release_frame(sink, frame, createSync(d, EGL_SYNC_FENCE_KHR, NULL));
        if (drawn++ % 50 == 0)
            printf("drew frame %d (gl 0x%x)\n", frame, glGetError());
        fflush(stdout);
    }
    printf("received %d, drawn %d, failed %d in %d s\n", received, drawn, failed, seconds);
    gst_element_set_state(play, GST_STATE_NULL);
    return 0;
}
