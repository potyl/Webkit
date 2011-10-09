#include <stdio.h>
#include <gtk/gtk.h>
#include <webkit/webkit.h>
#include <JavaScriptCore/JavaScript.h>


struct _Ctx {
    GMainLoop *loop;
};
typedef struct _Ctx Ctx;



static void
load_status_cb (GObject* object, GParamSpec* pspec, gpointer data);

static void
execute_js (WebKitWebView *web_view);


static void
load_status_cb (GObject* object, GParamSpec* pspec, gpointer data) {
    WebKitWebView *web_view;
    WebKitLoadStatus status;
    Ctx *ctx;

    ctx = (Ctx *) data;
    web_view = WEBKIT_WEB_VIEW(object);
    status = webkit_web_view_get_load_status(web_view);
    if (status != WEBKIT_LOAD_FINISHED) {return;}

    /* We now know that the document has been loaded */
    g_main_loop_quit(ctx->loop);

    execute_js(web_view);
}


static void
execute_js (WebKitWebView *web_view) {
    WebKitWebFrame *frame;
    JSGlobalContextRef context;
    JSStringRef js_script, js_value;
    JSValueRef value;
    gint size;
    gchar* str_value;

    frame = webkit_web_view_get_main_frame(web_view);
    context = webkit_web_frame_get_global_context(frame);

    js_script = JSStringCreateWithUTF8CString("window.document.getElementsByTagName('title')[0].innerText;");
    value = JSEvaluateScript(context, js_script, NULL, NULL, NULL, NULL);
    JSStringRelease(js_script);

    if (! JSValueIsString(context, value)) {
        printf("Value is not a string\n");
        return;
    }

    js_value = JSValueToStringCopy(context, value, NULL);
    size = JSStringGetMaximumUTF8CStringSize(js_value);
    str_value = g_malloc(size);
    JSStringGetUTF8CString(js_value, str_value, size);
    JSStringRelease(js_value);

    printf("Title: %s\n", str_value);
    g_free(str_value);
}


int
main (int argc, char* argv[]) {
    const char *uri;
    WebKitWebView *web_view;
    Ctx ctx;

    gtk_init(&argc, &argv);
  
    if (argc == 1) {
        printf("Usage: URI\n");
        return 1;
    }
    uri = argv[1];

    if (!g_thread_supported()) {g_thread_init(NULL);}

    web_view = WEBKIT_WEB_VIEW(webkit_web_view_new());
    g_object_ref_sink(G_OBJECT(web_view));
    g_signal_connect(web_view, "notify::load-status", G_CALLBACK(load_status_cb), &ctx);
    webkit_web_view_load_uri(web_view, uri);

    ctx.loop = g_main_loop_new(NULL, TRUE);
    g_main_loop_run(ctx.loop);
    g_object_unref(web_view);

    return 0;
}

