/* Fakes finger input on the phone through XTest, so UI checks don't need a person.
 * Commands run in order: p X Y (press), m X Y (move), r (release), w MS (wait).
 * X, Y are screen pixels (854x480). A long press and drag:
 *   xtouch p 300 200 w 1200 m 330 200 w 100 m 360 200 r
 * The SDK has no XTest header, so the two calls are declared here.
 * Build: $CC xtouch.c -I$SYSROOT/usr/include $SYSROOT/usr/lib/libXtst.so.6 -lX11 -o xtouch */
#include <X11/Xlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern int XTestFakeMotionEvent(Display *, int screen, int x, int y, unsigned long delay);
extern int XTestFakeButtonEvent(Display *, unsigned int button, Bool press, unsigned long delay);

int main(int argc, char **argv)
{
    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) {
        fprintf(stderr, "XOpenDisplay failed\n");
        return 1;
    }
    for (int i = 1; i < argc; ++i) {
        const char *c = argv[i];
        if ((!strcmp(c, "p") || !strcmp(c, "m")) && i + 2 < argc) {
            XTestFakeMotionEvent(dpy, -1, atoi(argv[i + 1]), atoi(argv[i + 2]), 0);
            if (*c == 'p')
                XTestFakeButtonEvent(dpy, 1, True, 0);
            i += 2;
        } else if (!strcmp(c, "r")) {
            XTestFakeButtonEvent(dpy, 1, False, 0);
        } else if (!strcmp(c, "w") && i + 1 < argc) {
            XFlush(dpy);
            usleep(atoi(argv[++i]) * 1000);
        } else {
            fprintf(stderr, "bad command %s\n", c);
            return 2;
        }
        XFlush(dpy);
    }
    XCloseDisplay(dpy);
    return 0;
}
