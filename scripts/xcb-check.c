/* Phase 1 check on the phone: our libxcb talks to the X server, the XKB extension
 * answers, xkbcommon-x11 builds a keymap from the core keyboard, and the system libX11
 * works on top of our libxcb (it needs Nokia's xcb_poll_for_next_event; run with
 * LD_BIND_NOW=1 so a missing symbol fails at startup).
 * Built and run by hand; see the Phase 1 and 2.2 log entries in PLAN.md. */
#include <stdio.h>
#include <string.h>
#include <X11/Xlib.h>
#include <xcb/xcb.h>
#include <xkbcommon/xkbcommon-x11.h>

int main(void)
{
    xcb_connection_t *c = xcb_connect(NULL, NULL);
    if (xcb_connection_has_error(c)) {
        puts("FAIL: xcb_connect");
        return 1;
    }
    const xcb_setup_t *setup = xcb_get_setup(c);
    xcb_screen_t *screen = xcb_setup_roots_iterator(setup).data;
    printf("X release %u, screen %ux%u\n", setup->release_number, screen->width_in_pixels, screen->height_in_pixels);

    if (!xkb_x11_setup_xkb_extension(c, XKB_X11_MIN_MAJOR_XKB_VERSION, XKB_X11_MIN_MINOR_XKB_VERSION,
                                     XKB_X11_SETUP_XKB_EXTENSION_NO_FLAGS, NULL, NULL, NULL, NULL)) {
        puts("FAIL: XKB extension");
        return 1;
    }
    int32_t device = xkb_x11_get_core_keyboard_device_id(c);
    struct xkb_context *ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    struct xkb_keymap *keymap = xkb_x11_keymap_new_from_device(ctx, c, device, XKB_KEYMAP_COMPILE_NO_FLAGS);
    if (!keymap) {
        puts("FAIL: keymap");
        return 1;
    }
    printf("XKB core keyboard %d: %u layouts, first \"%s\"\n", device, xkb_keymap_num_layouts(keymap),
           xkb_keymap_layout_get_name(keymap, 0));
    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) {
        puts("FAIL: XOpenDisplay");
        return 1;
    }
    XNoOp(dpy);
    XSync(dpy, False);
    printf("Xlib on our libxcb: %d events pending\n", XPending(dpy));
    XCloseDisplay(dpy);

    // Which copies of the replaced libraries got mapped: ours must win (Decisions).
    FILE *maps = fopen("/proc/self/maps", "r");
    char line[512];
    while (fgets(line, sizeof line, maps))
        if (strstr(line, "libxcb.so") || strstr(line, "libgcc_s"))
            if (strstr(line, "r-xp"))
                fputs(strchr(line, '/'), stdout);
    fclose(maps);
    puts("OK");
    return 0;
}
