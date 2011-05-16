#include <gtk/gtk.h>
#include <webkit/webkit.h>
#include <libsoup/soup.h>


static void
request_started_cb (SoupSession *session, SoupMessage *message, SoupSocket *socket, gpointer data);

static void
request_finished_cb (SoupMessage *message, gpointer data);

static void
tracker_end_cb (SoupMessage *message, gpointer data);

static void
load_status_cb (GObject* object, GParamSpec* pspec, gpointer data);


static void
request_started_cb (SoupSession *session, SoupMessage *message, SoupSocket *socket, gpointer data) {
    SoupURI *uri;
    char *uri_string;

    uri = soup_message_get_uri(message);
    uri_string = soup_uri_to_string(uri, FALSE);
    printf("Start download of %s\n", uri_string);
    g_free(uri_string);
    g_signal_connect(message, "finished", G_CALLBACK(request_finished_cb), NULL);
}


static void
request_finished_cb (SoupMessage *message, gpointer data) {
    SoupURI *uri;
    char *uri_string;

    uri = soup_message_get_uri(message);
    uri_string = soup_uri_to_string(uri, FALSE);
    printf("Finished download of %s\n", uri_string);
    g_free(uri_string);
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
    SoupSession *session;

    gtk_init(&argc, &argv);
  
    if (argc == 1) {
        printf("Usage: URI\n");
        return 1;
    }
    uri = argv[1];

    if (!g_thread_supported()) {g_thread_init(NULL);}

    loop = g_main_loop_new(NULL, TRUE);

    session = webkit_get_default_session();
    g_signal_connect(session, "request-started", G_CALLBACK(request_started_cb), NULL);

    web_view = WEBKIT_WEB_VIEW(webkit_web_view_new());
    g_object_ref_sink(G_OBJECT(web_view));

    g_signal_connect(web_view, "notify::load-status", G_CALLBACK(load_status_cb), loop);
    webkit_web_view_load_uri(web_view, uri);

    g_main_loop_run(loop);

    g_object_unref(web_view);

    return 0;
}

