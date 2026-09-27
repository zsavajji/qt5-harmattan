/* 3.3 helper: prints the CLIPBOARD owner, its UTF8_STRING text and its TARGETS whenever they
 * change (every 500 ms, for N seconds). No xclip on the phone.
 * Build: $CC xsel-owner.c -lX11 -o xsel-owner */
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>
static char *text(Display *d, Window me, Atom clip, Atom utf8, Atom prop)
{
    struct timeval t0, t1;
    gettimeofday(&t0, 0);
    XConvertSelection(d, clip, utf8, prop, me, CurrentTime);
    XFlush(d);
    for (int i = 0; i < 280; ++i) {
        XEvent e;
        if (XCheckTypedWindowEvent(d, me, SelectionNotify, &e)) {
            gettimeofday(&t1, 0);
            long ms = (t1.tv_sec - t0.tv_sec) * 1000 + (t1.tv_usec - t0.tv_usec) / 1000;
            if (ms > 100) fprintf(stdout, "  (%s answered after %ld ms)\n", XGetAtomName(d, utf8), ms);
            if (e.xselection.property == None) return strdup("<refused>");
            Atom type; int fmt; unsigned long n, after; unsigned char *data = 0;
            XGetWindowProperty(d, me, prop, 0, 1024, True, AnyPropertyType, &type, &fmt, &n, &after, &data);
            char *s;
            if (type == XA_ATOM) {
                s = malloc(1024); s[0] = 0;
                for (unsigned long k = 0; k < n; ++k) { strcat(s, XGetAtomName(d, ((Atom *)data)[k])); strcat(s, " "); }
            } else
                s = strdup(data ? (char *)data : "<none>");
            if (data) XFree(data);
            return s;
        }
        usleep(25000);
    }
    return strdup("<timeout>");
}
int main(int argc, char **argv)
{
    Display *d = XOpenDisplay(NULL);
    if (!d) return 1;
    Atom clip = XInternAtom(d, "CLIPBOARD", False), utf8 = XInternAtom(d, "UTF8_STRING", False);
    Atom prop = XInternAtom(d, "XSEL_OWNER_DATA", False);
    Window me = XCreateSimpleWindow(d, DefaultRootWindow(d), 0, 0, 1, 1, 0, 0, 0);
    int n = argc > 1 ? atoi(argv[1]) * 2 : 30;
    char last[512] = "";
    for (int i = 0; i < n; ++i) {
        Window w = XGetSelectionOwner(d, clip);
        char *t = w ? text(d, me, clip, utf8, prop) : strdup("");
        char *tg = w ? text(d, me, clip, XInternAtom(d, "TARGETS", False), prop) : strdup("");
        char *both = malloc(strlen(t) + strlen(tg) + 16);
        sprintf(both, "%s] targets [%s", t, tg);
        free(t); free(tg); t = both;
        char line[512];
        snprintf(line, sizeof line, "owner 0x%lx [%s]", w, t);
        free(t);
        if (strcmp(line, last)) {
            struct timeval tv; gettimeofday(&tv, 0);
            printf("%ld.%03ld %s\n", tv.tv_sec % 1000, tv.tv_usec / 1000, line);
            fflush(stdout);
            strcpy(last, line);
        }
        usleep(500000);
    }
    return 0;
}
