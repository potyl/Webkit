#include <gtk/gtk.h>
#include <webkit/webkit.h>
#include <libsoup/soup.h>
#include <cairo-pdf.h>


static void
save_as_pdf (GtkWidget *widget, const char *filename) {
    GtkAllocation allocation;

    gtk_widget_get_allocation(widget, &allocation);
    cairo_surface_t *surface = cairo_pdf_surface_create(
        filename,
        1.0 * allocation.width,
        1.0 * allocation.height
    );

    cairo_t *cr = cairo_create(surface);
    gtk_widget_draw(widget, cr);
    cairo_destroy(cr);
    cairo_surface_destroy(surface);
}


static void
load_status_cb (GObject* object, GParamSpec* pspec, gpointer data) {
    WebKitWebView *web_view = WEBKIT_WEB_VIEW(object);
    WebKitLoadStatus status = webkit_web_view_get_load_status(web_view);
    if (status != WEBKIT_LOAD_FINISHED) {
        return;
    }

    save_as_pdf(GTK_WIDGET(web_view), (const gchar *) data);

    gtk_main_quit();
}


int
main (int argc, gchar* argv[]) {
    gtk_init(&argc, &argv);

    if (argc < 2) {
        printf("Usage: URI [filename]\n");
        return 1;
    }
    const gchar *uri = argv[1];
    const gchar *filename = argc > 2 ? argv[2] : "a.pdf";

    if (!g_thread_supported()) {g_thread_init(NULL);}

    WebKitWebView *web_view = WEBKIT_WEB_VIEW(webkit_web_view_new());
    g_signal_connect(web_view, "notify::load-status", G_CALLBACK(load_status_cb), (gpointer) filename);

    GtkWidget *offscren = gtk_offscreen_window_new();
    gtk_container_add(GTK_CONTAINER(offscren), GTK_WIDGET(web_view));
    gtk_widget_show_all(offscren);

    webkit_web_view_load_uri(web_view, uri);
    gtk_main();

    return 0;
}

