#include <gtk/gtk.h>
#include <webkit/webkit.h>
#include <libsoup/soup.h>


static void
load_status_cb (GObject* object, GParamSpec* pspec, gpointer data);


static void
process_web_view (WebKitWebView *web_view) {

    WebKitDOMDocument *document = webkit_web_view_get_dom_document(web_view);

    WebKitDOMStyleSheetList *style_sheets = webkit_dom_document_get_style_sheets(document);
    printf("Got document %p\n", style_sheets);
    gulong style_sheet_length = webkit_dom_style_sheet_list_get_length(style_sheets);

    for (gulong i = 0; i < style_sheet_length; ++i) {
        WebKitDOMStyleSheet *style_sheet = webkit_dom_style_sheet_list_item(style_sheets, i);
        printf("Style sheet %d = %p\n", (int) i, style_sheet);

        webkit_dom_style_sheet_get_css_rules(style_sheet);
//cssRules

//        WebKitDOMCSSRuleList *rules = webkit_dom_style_sheet_get_css_rules(style_sheet);
//        gulong rules_length = webkit_dom_css_rule_list_get_length(rules);
//        for (gulong j = 0; j < style_sheet_length; ++j) {
//            WebKitDOMCSSRule *rule = webkit_dom_css_rule_list_item(rules, j);
//            printf("Rule %d = %p\n", (int) j, rule);
//        }
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

