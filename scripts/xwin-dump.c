/* 3.2 helper: for every window in the root's _NET_CLIENT_LIST (plus the root itself with
 * -r, every child of the root whose WM_CLASS contains NAME with -t NAME, or one window with
 * -w ID), print its properties: atoms by name, CARDINAL/WINDOW/INTEGER as numbers, strings as
 * text. Used to compare Qt 5 windows with the stock Qt 4 apps' windows. No xprop on the
 * phone. Build: $CC xwin-dump.c $(pkg-config --cflags --libs xcb) -o xwin-dump */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xcb/xcb.h>

static xcb_connection_t *c;

static const char *atom_name(xcb_atom_t a)
{
    static char buf[256];
    xcb_get_atom_name_reply_t *r = xcb_get_atom_name_reply(c, xcb_get_atom_name(c, a), NULL);
    if (!r)
        return "?";
    snprintf(buf, sizeof buf, "%.*s", xcb_get_atom_name_name_length(r), xcb_get_atom_name_name(r));
    free(r);
    return buf;
}

static xcb_atom_t intern(const char *name)
{
    xcb_intern_atom_reply_t *r = xcb_intern_atom_reply(c, xcb_intern_atom(c, 0, strlen(name), name), NULL);
    xcb_atom_t a = r ? r->atom : XCB_NONE;
    free(r);
    return a;
}

static void dump(xcb_window_t w)
{
    xcb_get_window_attributes_reply_t *attr = xcb_get_window_attributes_reply(c, xcb_get_window_attributes(c, w), NULL);
    printf("window 0x%x map_state=%d override_redirect=%d\n", w, attr ? attr->map_state : -1,
           attr ? attr->override_redirect : -1);
    free(attr);
    xcb_get_geometry_reply_t *g = xcb_get_geometry_reply(c, xcb_get_geometry(c, w), NULL);
    if (g) {
        xcb_translate_coordinates_reply_t *t = xcb_translate_coordinates_reply(
            c, xcb_translate_coordinates(c, w, g->root, 0, 0), NULL);
        printf("  geometry %ux%u at %d,%d on screen\n", g->width, g->height, t ? t->dst_x : -1, t ? t->dst_y : -1);
        free(t);
        free(g);
    }
    xcb_list_properties_reply_t *lp = xcb_list_properties_reply(c, xcb_list_properties(c, w), NULL);
    if (!lp)
        return;
    xcb_atom_t *props = xcb_list_properties_atoms(lp);
    for (int i = 0; i < xcb_list_properties_atoms_length(lp); i++) {
        xcb_get_property_reply_t *p = xcb_get_property_reply(c, xcb_get_property(c, 0, w, props[i], XCB_ATOM_ANY, 0, 64), NULL);
        if (!p)
            continue;
        char name[256];
        snprintf(name, sizeof name, "%s", atom_name(props[i]));
        if (!strcmp(name, "_NET_WM_ICON") || !strcmp(name, "_NET_CLIENT_LIST_STACKING")) {
            printf("  %s: (%d items)\n", name, xcb_get_property_value_length(p) / 4);
            free(p);
            continue;
        }
        char type[256];
        snprintf(type, sizeof type, "%s", atom_name(p->type));
        printf("  %s(%s) =", name, type);
        int n = xcb_get_property_value_length(p);
        const unsigned char *v = xcb_get_property_value(p);
        if (p->format == 8) {
            printf(" \"");
            for (int k = 0; k < n; k++)
                putchar(v[k] ? v[k] : '|');
            printf("\"");
        } else if (p->format == 32) {
            const uint32_t *u = (const uint32_t *)v;
            for (int k = 0; k < n / 4 && k < 16; k++) {
                if (p->type == XCB_ATOM_ATOM)
                    printf(" %s", atom_name(u[k]));
                else
                    printf(" %d", (int)u[k]);
            }
        } else if (p->format == 16) {
            printf(" (16-bit, %d bytes)", n);
        }
        printf("\n");
        free(p);
    }
    free(lp);
}

int main(int argc, char **argv)
{
    c = xcb_connect(NULL, NULL);
    if (xcb_connection_has_error(c)) {
        fprintf(stderr, "xcb_connect failed\n");
        return 1;
    }
    xcb_window_t root = xcb_setup_roots_iterator(xcb_get_setup(c)).data->root;
    if (argc > 1 && !strcmp(argv[1], "-r"))
        dump(root);
    if (argc > 2 && !strcmp(argv[1], "-w")) { // one window by id, e.g. a selection owner
        dump(strtoul(argv[2], NULL, 0));
        return 0;
    }
    if (argc > 2 && !strcmp(argv[1], "-t")) {
        xcb_query_tree_reply_t *t = xcb_query_tree_reply(c, xcb_query_tree(c, root), NULL);
        xcb_window_t *kids = xcb_query_tree_children(t);
        for (int i = 0; t && i < xcb_query_tree_children_length(t); i++) {
            xcb_get_property_reply_t *p = xcb_get_property_reply(
                c, xcb_get_property(c, 0, kids[i], XCB_ATOM_WM_CLASS, XCB_ATOM_STRING, 0, 64), NULL);
            if (p && xcb_get_property_value_length(p) > 0
                && memmem(xcb_get_property_value(p), xcb_get_property_value_length(p), argv[2], strlen(argv[2])))
                dump(kids[i]);
            free(p);
        }
        free(t);
        return 0;
    }
    xcb_get_property_reply_t *r = xcb_get_property_reply(
        c, xcb_get_property(c, 0, root, intern("_NET_CLIENT_LIST"), XCB_ATOM_WINDOW, 0, 256), NULL);
    if (!r)
        return 1;
    const xcb_window_t *wins = xcb_get_property_value(r);
    for (int i = 0; i < xcb_get_property_value_length(r) / 4; i++)
        dump(wins[i]);
    free(r);
    xcb_disconnect(c);
    return 0;
}
