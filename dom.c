#include <gtk/gtk.h>
#include <webkit/webkit.h>
#include <libsoup/soup.h>


static void
load_status_cb (GObject* object, GParamSpec* pspec, gpointer data);


static void
process_web_view (WebKitWebView *web_view) {

    WebKitDOMDocument *document = webkit_web_view_get_dom_document(web_view);

    GError *error;
    WebKitDOMXPathNSResolver *resolver = webkit_dom_document_create_ns_resolver(document, (WebKitDOMNode *) document);
    WebKitDOMXPathResult *result = webkit_dom_document_evaluate(document, "//*", (WebKitDOMNode *) document, resolver, 0, NULL, &error);
    printf("XPath returned: %p\n", result);


    gushort type = webkit_dom_xpath_result_get_result_type(result);
    printf("Type: %d\n", type);
    gchar *str = webkit_dom_xpath_result_get_string_value(result, &error);
    printf("STring: %s\n", str);
    g_free(str);


    while (1) {
        WebKitDOMNode *node = webkit_dom_xpath_result_iterate_next(result, &error);
        if (node == NULL) {
            break;
        }

        WebKitDOMElement *element = (WebKitDOMElement *) node;

        printf("%s\n", webkit_dom_element_get_tag_name(element));


        WebKitDOMCSSStyleDeclaration *style_declaration = webkit_dom_element_get_style(element);
        printf("style_declaration %s\n",
            G_OBJECT_TYPE_NAME(style_declaration)
        );

        gchar *css_text = webkit_dom_css_style_declaration_get_css_text(style_declaration);
        printf("  css:%s\n", css_text);
        printf("\n");
    }


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

