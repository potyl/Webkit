#include <gtk/gtk.h>
#include <webkit/webkit.h>
#include <libsoup/soup.h>


static void
tracker_start_cb (WebKitWebView *web_view, WebKitWebFrame *web_frame, WebKitWebResource *web_resource, WebKitNetworkRequest *request, WebKitNetworkResponse *response, gpointer user_data);

static void
tracker_end_cb (SoupMessage *message, gpointer data);

static void
load_status_cb (GObject* object, GParamSpec* pspec, gpointer data);


static void
tracker_start_cb (WebKitWebView *web_view, WebKitWebFrame *web_frame, WebKitWebResource *web_resource, WebKitNetworkRequest *request, WebKitNetworkResponse *response, gpointer user_data) {
    SoupMessage *message;
    const char *uri;
    
    uri = webkit_network_request_get_uri(request);
    if (strcmp(uri, "about:blank") == 0) {return;}
    
    message = webkit_network_request_get_message(request);
    if (message == NULL) {
        printf("Can't get message for %s\n", uri);
        return;
    }
    printf("Start download of %s\n", uri);
    g_signal_connect(message, "finished", G_CALLBACK(tracker_end_cb), request);
}


static void
tracker_end_cb (SoupMessage *message, gpointer data) {
    WebKitNetworkRequest *request;
    request = (WebKitNetworkRequest *) data;
    printf("Finished download of %s\n", webkit_network_request_get_uri(request));
}


static void
load_status_cb (GObject* object, GParamSpec* pspec, gpointer data) {
    WebKitWebView *web_view;
    WebKitLoadStatus status;
    GMainLoop* loop;

    loop = (GMainLoop *) data;

    web_view = WEBKIT_WEB_VIEW(object);
    status = webkit_web_view_get_load_status(web_view);
    if (status == WEBKIT_LOAD_FINISHED) {
        printf("Finished with %s\n", webkit_web_view_get_uri(web_view));
        g_main_loop_quit(loop);
    }
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

    g_signal_connect(web_view, "resource-request-starting", G_CALLBACK(tracker_start_cb), NULL);
    g_signal_connect(web_view, "notify::load-status", G_CALLBACK(load_status_cb), loop);
    webkit_web_view_load_uri(web_view, uri);

    g_main_loop_run(loop);

    g_object_unref(web_view);

    return 0;
}

