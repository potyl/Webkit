#include <gtk/gtk.h>
#include <webkit/webkit.h>
#include <JavaScriptCore/JavaScriptCore.h>


static void
load_status_cb (GObject* object, GParamSpec* pspec, gpointer data);


static void
process_web_view (WebKitWebView *web_view) {
    WebKitWebFrame *web_frame = webkit_web_view_get_main_frame(web_view);
    JSGlobalContextRef jsref = webkit_web_frame_get_global_context(web_frame);
    printf("Size of JSGlobalContextRef = %i\n", sizeof(JSGlobalContextRef));

    JSValueRef jsUndefined = JSValueMakeUndefined(context);
    JSValueRef jsNull = JSValueMakeNull(context);
    JSValueRef jsTrue = JSValueMakeBoolean(context, true);
    JSValueRef jsFalse = JSValueMakeBoolean(context, false);
    JSValueRef jsZero = JSValueMakeNumber(context, 0);
    JSValueRef jsOne = JSValueMakeNumber(context, 1);
    JSValueRef jsOneThird = JSValueMakeNumber(context, 1.0 / 3.0);
    JSObjectRef jsObjectNoProto = JSObjectMake(context, NULL, NULL);
    JSObjectSetPrototype(context, jsObjectNoProto, JSValueMakeNull(context));
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
        process_web_view(web_view);
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

    g_signal_connect(web_view, "notify::load-status", G_CALLBACK(load_status_cb), loop);
    webkit_web_view_load_uri(web_view, uri);

    g_main_loop_run(loop);
    g_object_unref(web_view);

    return 0;
}

