#include <stdio.h>
#include <gtk/gtk.h>
#include <webkit/webkit.h>

#define DOM_NODE_TYPE_ELEMENT 1
#define DOM_NODE_TYPE_ATTRIBUTE 2
#define DOM_NODE_TYPE_TEXT 3
#define DOM_NODE_TYPE_CDATA_SECTION 4
#define DOM_NODE_TYPE_ENTITY_REFERENCE 5
#define DOM_NODE_TYPE_ENTITY 6
#define DOM_NODE_TYPE_PROCESSING_INSTRUCTION 7
#define DOM_NODE_TYPE_COMMENT 8
#define DOM_NODE_TYPE_DOCUMENT 9
#define DOM_NODE_TYPE_DOCUMENT_TYPE 10
#define DOM_NODE_TYPE_DOCUMENT_FRAGMENT 11
#define DOM_NODE_TYPE_NOTATION 12

#define TO_MS(mtime) ( (gint64) ((mtime)/1000) )

struct _Ctx {
    GMainLoop *loop;
    gint64 start_time;
};
typedef struct _Ctx Ctx;


static gulong
walk_dom (WebKitDOMNode *node);

static void
load_status_cb (GObject* object, GParamSpec* pspec, gpointer data);

static gboolean
console_message_cb (gchar *message, gint line, gchar *source_id);


static gulong
walk_dom (WebKitDOMNode *node) {
    WebKitDOMNodeList *list;
    gulong i, length, count;

    if (! webkit_dom_node_has_child_nodes(node)) {return 1;}

    list = webkit_dom_node_get_child_nodes(node);
    length = webkit_dom_node_list_get_length(list);
    count = 1;
    for (i = 0; i < length; ++i) {
        WebKitDOMNode *child_node;
        child_node = webkit_dom_node_list_item(list, i);
        count += walk_dom(child_node);
    }
    g_object_unref(list);

    return count;
}


static void
load_status_cb (GObject* object, GParamSpec* pspec, gpointer data) {
    WebKitDOMDocument *document;
    WebKitWebView *web_view;
    WebKitLoadStatus status;
    Ctx *ctx;
    gulong count;
    gint64 now, elapsed;

    ctx = (Ctx *) data;
    web_view = WEBKIT_WEB_VIEW(object);
    status = webkit_web_view_get_load_status(web_view);
    if (status != WEBKIT_LOAD_FINISHED) {return;}

    /* We now know that the document has been loaded */
    g_main_loop_quit(ctx->loop);
    now = g_get_monotonic_time();
    printf("Document loaded in %lldms\n", TO_MS(now - (ctx->start_time)));

    document = webkit_web_view_get_dom_document(web_view);
    count = walk_dom(WEBKIT_DOM_NODE(document));
    elapsed = g_get_monotonic_time() - now;
    printf("Document has %ld nodes and took %lldms to walk\n", count, TO_MS(elapsed));
}


static gboolean
console_message_cb (gchar *message, gint line, gchar *source_id) {
    return TRUE;
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
    g_signal_connect(web_view, "console-message", G_CALLBACK(console_message_cb), NULL);
    webkit_web_view_load_uri(web_view, uri);

    ctx.loop = g_main_loop_new(NULL, TRUE);
    ctx.start_time = g_get_monotonic_time();
    g_main_loop_run(ctx.loop);
    g_object_unref(web_view);

    return 0;
}

