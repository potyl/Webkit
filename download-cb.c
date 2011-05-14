#include <gtk/gtk.h>
#include <webkit/webkit.h>
#include <libsoup/soup.h>

static void destroy_cb(GtkWidget *widget, gpointer data);
static void tracker_start_cb (WebKitWebView *webView, WebKitWebFrame *web_frame, WebKitWebResource *web_resource, WebKitNetworkRequest *request, WebKitNetworkResponse *response, gpointer user_data);
static void tracker_end_cb(SoupMessage *messag, gpointer data);



static void destroy_cb(GtkWidget *widget, gpointer data) {
  gtk_main_quit();
}

static void resource_change_cb(GObject* object, GParamSpec* pspec, gpointer data) {
    WebKitWebResource *web_resource;
    
    web_resource = (WebKitWebResource *) object;
    
    printf("**** %s\n", webkit_web_resource_get_uri(web_resource));
}


static void load_status_cb(GObject* object, GParamSpec* pspec, gpointer data) {
    printf("**** load status called\n");
}


static void tracker_start_cb (WebKitWebView *web_view, WebKitWebFrame *web_frame, WebKitWebResource *web_resource, WebKitNetworkRequest *request, WebKitNetworkResponse *response, gpointer user_data) {
    SoupMessage *message;
    const char *uri;
    int code;
    char *method;
    
    uri = webkit_network_request_get_uri(request);
    if (strcmp(uri, "about:blank") == 0) {return;}
    
    message = webkit_network_request_get_message(request);
    if (message == NULL) {
        printf("Can't get message for %s\n", uri);
        return;
    }
    printf("Message is %p\n", message);
    g_object_get(
        message,
        "status-code", &code,
        "method", &method,
        NULL
    );
    printf("Download of %s code: %d; method: %s\n", uri, code, method);
    
    g_signal_connect(message, "notify::encoding", G_CALLBACK(resource_change_cb), request);
    g_signal_connect(message, "notify::satus-code", G_CALLBACK(resource_change_cb), request);
    g_signal_connect(message, "finished", G_CALLBACK(tracker_end_cb), request);
    g_signal_connect(web_resource, "notify::encoding", G_CALLBACK(resource_change_cb), NULL);
}


static void tracker_end_cb(SoupMessage *message, gpointer data) {
    WebKitNetworkRequest *request;
    request = (WebKitNetworkRequest *) data;
    printf("Downloaded %s\n", webkit_network_request_get_uri(request));
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

  if (!g_thread_supported()) {g_thread_init(NULL);}

  window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_default_size(GTK_WINDOW(window), 600, 400);
  g_signal_connect(window, "destroy", G_CALLBACK(destroy_cb), NULL);

  web_view = WEBKIT_WEB_VIEW(webkit_web_view_new());

  g_signal_connect(web_view, "resource-request-starting", G_CALLBACK(tracker_start_cb), NULL);
//    g_object_connect(web_view, "signal::notify::load-status", &load_status_cb, NULL, NULL);

  webkit_web_view_load_uri(web_view, uri);

  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(web_view));
  gtk_widget_grab_focus(GTK_WIDGET(web_view));
  gtk_widget_show_all(window);
  gtk_main();
  return 0;
}

