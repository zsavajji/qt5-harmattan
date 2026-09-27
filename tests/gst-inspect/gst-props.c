/* Prints a GStreamer 0.10 element's properties (type, default, range) and signals; the phone
 * has no gst-inspect. Usage: gst-props gltexturesink */
#include <gst/gst.h>
#include <stdio.h>

int main(int argc, char **argv)
{
    gst_init(&argc, &argv);
    GstElement *e = gst_element_factory_make(argc > 1 ? argv[1] : "gltexturesink", NULL);
    if (!e) { fprintf(stderr, "no element\n"); return 1; }
    guint n; GParamSpec **ps = g_object_class_list_properties(G_OBJECT_GET_CLASS(e), &n);
    for (guint i = 0; i < n; ++i) {
        GValue v = { 0 };
        g_value_init(&v, ps[i]->value_type);
        g_param_value_set_default(ps[i], &v);
        gchar *def = g_strdup_value_contents(&v);
        printf("%-24s %-16s default %s", ps[i]->name, g_type_name(ps[i]->value_type), def);
        if (G_IS_PARAM_SPEC_INT(ps[i]))
            printf(" [%d..%d]", G_PARAM_SPEC_INT(ps[i])->minimum, G_PARAM_SPEC_INT(ps[i])->maximum);
        if (G_IS_PARAM_SPEC_ENUM(ps[i])) {
            GEnumClass *ec = G_PARAM_SPEC_ENUM(ps[i])->enum_class;
            for (guint k = 0; k < ec->n_values; ++k)
                printf(" %d=%s", ec->values[k].value, ec->values[k].value_nick);
        }
        printf("  -- %s\n", g_param_spec_get_blurb(ps[i]));
        g_free(def); g_value_unset(&v);
    }
    for (GType t = G_OBJECT_TYPE(e); t; t = g_type_parent(t)) {
        guint ns; guint *ids = g_signal_list_ids(t, &ns);
        for (guint i = 0; i < ns; ++i) {
            GSignalQuery q; g_signal_query(ids[i], &q);
            printf("signal %s(", q.signal_name);
            for (guint k = 0; k < q.n_params; ++k)
                printf("%s%s", k ? ", " : "", g_type_name(q.param_types[k]));
            printf(") -> %s\n", g_type_name(q.return_type));
        }
        g_free(ids);
        if (t == GST_TYPE_ELEMENT) break;
    }
    GType *ifaces = g_type_interfaces(G_OBJECT_TYPE(e), &n);
    for (guint i = 0; i < n; ++i) {
        printf("interface %s\n", g_type_name(ifaces[i]));
        guint ns; guint *ids = g_signal_list_ids(ifaces[i], &ns);
        for (guint j = 0; j < ns; ++j) {
            GSignalQuery q; g_signal_query(ids[j], &q);
            printf("  signal %s(", q.signal_name);
            for (guint k = 0; k < q.n_params; ++k)
                printf("%s%s", k ? ", " : "", g_type_name(q.param_types[k]));
            printf(") -> %s\n", g_type_name(q.return_type));
        }
        g_free(ids);
    }
    if (g_object_class_find_property(G_OBJECT_GET_CLASS(e), "modes-supported")) {
        GList *modes = NULL;
        g_object_get(e, "modes-supported", &modes, NULL);
        for (GList *l = modes; l; l = l->next) printf("render-mode value: %s\n", (const char *)l->data);
    }
    return 0;
}
