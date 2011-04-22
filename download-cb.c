#include <gtk/gtk.h>
#include <webkit/webkit.h>

static void destroy_cb(GtkWidget* widget, gpointer data) {
  gtk_main_quit();
}

static void load_finished_cb(WebKitWebView *web_view, WebKitWebFrame *web_frame, gpointer data) {
    printf("Finished downloading %s\n", webkit_web_view_get_uri(web_view));
}

static void load_status_cb(GObject* object, GParamSpec* pspec, gpointer data) {
    WebKitWebView *web_view;
    WebKitLoadStatus status;
    const gchar *uri;
    
    web_view = WEBKIT_WEB_VIEW(object);
    status = webkit_web_view_get_load_status(web_view);
    uri = webkit_web_view_get_uri(web_view);

    switch (status) {
    case WEBKIT_LOAD_PROVISIONAL:
        printf("Load provisional: %s\n", uri);
        break;
    case WEBKIT_LOAD_COMMITTED:
        printf("Load commited: %s\n", uri);
        break;
    case WEBKIT_LOAD_FIRST_VISUALLY_NON_EMPTY_LAYOUT:
        printf("Load first visually non empty layout: %s\n", uri);
        break;
    case WEBKIT_LOAD_FINISHED:
        printf("Load finished: %s\n", uri);
        break;
    default:
        g_assert_not_reached();
    }
}

int main(int argc, char* argv[]) {
  const char *uri;
  GtkWidget* window;
  WebKitWebView* web_view;

  gtk_init(&argc, &argv);
  
  if (argc == 1) {
  	printf("Usage: URI\n");
  	return 1;
  }
  uri = argv[1];

  if(!g_thread_supported())
    g_thread_init(NULL);

  window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_default_size(GTK_WINDOW(window), 600, 400);
  g_signal_connect(window, "destroy", G_CALLBACK(destroy_cb), NULL);

  web_view = web_view = WEBKIT_WEB_VIEW(webkit_web_view_new());
  webkit_web_view_set_transparent(web_view, TRUE);

  /* Register a callback that gets invoked each time that a page is finished downloading */
  g_signal_connect(web_view, "load-finished", G_CALLBACK(load_finished_cb), NULL);

  /* Register a callback that gets invoked each time that the load status changes */
  g_object_connect(web_view, "signal::notify::load-status", G_CALLBACK(load_status_cb), NULL);

  webkit_web_view_load_uri(web_view, uri);

  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(web_view));
  gtk_widget_grab_focus(GTK_WIDGET(web_view));
  gtk_widget_show_all(window);
  gtk_main();
  return 0;
}

