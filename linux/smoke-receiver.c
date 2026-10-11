#include <gtk/gtk.h>
#include <glib/gstdio.h>
#include <X11/Xlib.h>
#include <stdlib.h>
#include <string.h>

static const gchar *result_path;

static void on_destroy(GtkWidget *widget, gpointer data) {
    (void)widget; (void)data;
    gtk_main_quit();
}

static void on_received(GtkWidget *widget, GdkDragContext *context, gint x, gint y,
                        GtkSelectionData *selection, guint info, guint time, gpointer data) {
    (void)widget; (void)x; (void)y; (void)info; (void)data;
    gchar **uris = gtk_selection_data_get_uris(selection);
    gboolean success = FALSE;
    if (uris && uris[0]) {
        gchar *path = g_filename_from_uri(uris[0], NULL, NULL);
        gchar *contents = NULL;
        gsize length = 0;
        if (path && g_file_get_contents(path, &contents, &length, NULL)) {
            success = g_file_set_contents(result_path, contents, (gssize)length, NULL);
            g_free(contents);
        }
        g_free(path);
    }
    g_strfreev(uris);
    gtk_drag_finish(context, success, FALSE, time);
    gtk_main_quit();
}

int main(int argc, char **argv) {
    /* Request normal GTK close handling even under Xvfb without a window manager. */
    if (argc == 3 && strcmp(argv[1], "--close") == 0) {
        char *end = NULL;
        Window target = (Window)strtoul(argv[2], &end, 0);
        if (!target || !end || *end) return 2;
        Display *display = XOpenDisplay(NULL);
        if (!display) return 3;
        XEvent event = {0};
        event.xclient.type = ClientMessage;
        event.xclient.window = target;
        event.xclient.message_type = XInternAtom(display, "WM_PROTOCOLS", False);
        event.xclient.format = 32;
        event.xclient.data.l[0] = (long)XInternAtom(display, "WM_DELETE_WINDOW", False);
        event.xclient.data.l[1] = CurrentTime;
        Status sent = XSendEvent(display, target, False, NoEventMask, &event);
        XSync(display, False);
        XCloseDisplay(display);
        return sent ? 0 : 4;
    }
    if (argc != 2) return 2;
    result_path = argv[1];
    gtk_init(&argc, &argv);
    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "PromptSlip test receiver");
    gtk_window_set_default_size(GTK_WINDOW(window), 320, 180);
    GtkWidget *label = gtk_label_new("Drop a file URI here");
    gtk_container_add(GTK_CONTAINER(window), label);
    GtkTargetEntry targets[] = { { "text/uri-list", 0, 0 } };
    gtk_drag_dest_set(window, GTK_DEST_DEFAULT_ALL, targets, G_N_ELEMENTS(targets), GDK_ACTION_COPY);
    g_signal_connect(window, "drag-data-received", G_CALLBACK(on_received), NULL);
    g_signal_connect(window, "destroy", G_CALLBACK(on_destroy), NULL);
    gtk_widget_show_all(window);
    gtk_main();
    return 0;
}
