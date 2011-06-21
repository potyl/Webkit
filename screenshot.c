#include <gtk/gtk.h>
#include <webkit/webkit.h>
#include <libsoup/soup.h>

#include <cairo-pdf.h>


static void
load_status_cb (GObject* object, GParamSpec* pspec, gpointer data);


static void
load_status_cb (GObject* object, GParamSpec* pspec, gpointer data) {
    GMainLoop *loop = (GMainLoop *) data;

    WebKitWebView *web_view = WEBKIT_WEB_VIEW(object);
    WebKitLoadStatus status = webkit_web_view_get_load_status(web_view);
    if (status != WEBKIT_LOAD_FINISHED) {
        return;
    }

    GtkAllocation allocation;
    gtk_widget_get_allocation(GTK_WIDGET(web_view), &allocation);

    const char *filename = "a.pdf";
    cairo_surface_t *surface = cairo_pdf_surface_create(
        filename,
        1.0 * allocation.width,
        1.0 * allocation.height
    );

    cairo_t *cr = cairo_create(surface);
//    gtk_widget_draw(gtk_widget_get_parent(GTK_WIDGET(web_view)), cr);
    gtk_widget_draw(GTK_WIDGET(web_view), cr);
    cairo_destroy(cr);
    cairo_surface_destroy(surface);

    printf("Finished with %s; pdf saved as %s\n", webkit_web_view_get_uri(web_view), filename);
    g_main_loop_quit(loop);
}


int
main (int argc, char* argv[]) {
    const char *uri;
    WebKitWebView* web_view;
    GMainLoop* loop;

    gtk_init(&argc, &argv);

    if (argc == 1) {
        printf("Usage: URI\n");
        return 1;
    }
    uri = argv[1];

    if (!g_thread_supported()) {g_thread_init(NULL);}

    loop = g_main_loop_new(NULL, TRUE);

    web_view = WEBKIT_WEB_VIEW(webkit_web_view_new());
    g_object_ref_sink(G_OBJECT(web_view));

    g_signal_connect(web_view, "notify::load-status", G_CALLBACK(load_status_cb), loop);
    webkit_web_view_load_uri(web_view, uri);

    GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
//    gtk_window_set_default_size(GTK_WINDOW(window), 600, 400);
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
    gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(web_view));
    gtk_widget_show_all(window);

    g_main_loop_run(loop);
    g_object_unref(web_view);

    return 0;
}

