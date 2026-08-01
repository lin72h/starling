// System GStreamer (core + app library, for appsink). Exists so SwiftPM's
// pkg-config integration (gstreamer-app-1.0) supplies the include paths to
// the YouTube example — nothing hardcodes /usr/include/gstreamer-1.0.
//
// The static-inline helpers wrap what Swift cannot import: variadic
// g_object_set, and the G_TYPE_* / GST_*-cast macros.
#include <gst/gst.h>
#include <gst/app/gstappsink.h>

static inline void cgst_set_string(GstElement *element, const char *property,
                                   const char *value) {
    GValue v = G_VALUE_INIT;
    g_value_init(&v, G_TYPE_STRING);
    g_value_set_string(&v, value);
    g_object_set_property(G_OBJECT(element), property, &v);
    g_value_unset(&v);
}

static inline void cgst_set_object(GstElement *element, const char *property,
                                   GstElement *value) {
    GValue v = G_VALUE_INIT;
    g_value_init(&v, G_TYPE_OBJECT);
    g_value_set_object(&v, value);
    g_object_set_property(G_OBJECT(element), property, &v);
    g_value_unset(&v);
}

static inline void cgst_set_double(GstElement *element, const char *property,
                                   double value) {
    GValue v = G_VALUE_INIT;
    g_value_init(&v, G_TYPE_DOUBLE);
    g_value_set_double(&v, value);
    g_object_set_property(G_OBJECT(element), property, &v);
    g_value_unset(&v);
}

static inline GstBin *cgst_as_bin(GstElement *element) {
    return GST_BIN(element);
}

static inline GstAppSink *cgst_as_appsink(GstElement *element) {
    return GST_APP_SINK(element);
}

static inline GstSeekFlags cgst_seek_flags(void) {
    return (GstSeekFlags)(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_KEY_UNIT);
}
