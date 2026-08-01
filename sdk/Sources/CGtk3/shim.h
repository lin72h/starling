// System GTK 3. Exists so SwiftPM's pkg-config integration (gtk+-3.0)
// supplies the GTK/GLib include paths to every target that depends on this
// one — nothing in the package hardcodes /usr/include/gtk-3.0 and friends.
#include <gtk/gtk.h>
