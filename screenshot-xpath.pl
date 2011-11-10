#!/usr/bin/env perl

=head1 NAME

screenshot-xpath.pl - Take a screenshot for a given element

=head1 SYNOPSIS

screenshot-xpath.pl [OPTION]... [URI [XPATH]]

    -h, --help             print this help message
    -o, --output FILE      the screenshot file name
    -s, --size   SIZE      the window's size (ex: 1024x800)

Simple usage:

    screenshot-xpath.pl http://www.google.com/ 'id("hplogo")'

=head1 DESCRIPTION

Take a screenshot of an element.

=cut

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long qw(:config auto_help);
use Pod::Usage;

use Glib ':constants';
use Glib::Object::Introspection;
use Gtk3 -init;
use Gtk3::WebKit;
use Cairo::GObject;

use constant DOM_TYPE_ELEMENT => 1;
use constant DOM_TYPE_DOCUMENT => 9;
use constant ORDERED_NODE_SNAPSHOT_TYPE => 7;


sub main {
    GetOptions(
        'o|output=s' => \my $filename,
        's|size=s'   => \my $geometry,
    ) or pod2usage(1);
    my ($url, $xpath) = @ARGV;
    $url ||= 'http://localhost:3001/';
    $xpath ||= '/';
    $filename = 'screenshot.png' unless defined $filename;

    my $view = Gtk3::WebKit::WebView->new();
    $view->signal_connect('notify::load-status' => sub {
        return unless $view->get_uri and ($view->get_load_status eq 'finished');

        # Sometimes the program dies with:
        #  (<unknown>:19092): Gtk-CRITICAL **: gtk_widget_draw: assertion `!widget->priv->alloc_needed' failed
        # This seem to happend is there's a newtwork error and we can't download
        # external stuff (e.g. facebook iframe). This timeout seems to help a bit.
        Glib::Idle->add( sub {
            save_as_png($view, $filename, $xpath);
            Gtk3->main_quit();
        });
    });
    $view->load_uri($url);


    my $window = Gtk3::OffscreenWindow->new();
    if ( my ($w, $h) = ($geometry =~ /^ ([0-9]+) x ([0-9]+) $/x) ) {
        $window->set_default_size($w, $h);
    }

    # Set the main window transparent
    my $screen = $window->get_screen;
    $window->set_visual($screen->get_rgba_visual || $screen->get_system_visual);
    $view->set_transparent(TRUE);

    $window->add($view);
    $window->show_all();

    Gtk3->main();
    return 0;
}


sub save_as_png {
    my ($view, $filename, $xpath) = @_;

    # Get the first element returned by the XPath query and return it's offsets
    my $element = get_xpath_element($view->get_dom_document, $xpath);
    my ($left, $top, $width, $height) = get_offsets($element);

    my $surface = Cairo::ImageSurface->create(argb32 => $width, $height);
    my $cr = Cairo::Context->create($surface);
    $cr->translate(-$left, -$top);
    $view->draw($cr);
    $surface->write_to_png($filename);
    print "$filename has size: $width x $height\n";
}


sub get_xpath_element {
    my ($doc, $xpath) = @_;

    # Execute the XPath expression
    my $resolver = $doc->create_ns_resolver($doc);
    my $xpath_results = $doc->evaluate(
        $xpath,
        $doc,
        $resolver,
        ORDERED_NODE_SNAPSHOT_TYPE,
    );
    if (! $xpath_results or $xpath_results->get_snapshot_length == 0) {
        print "Can't find $xpath\n";
        return;
    }

    # We always return the first element
    my $element = $xpath_results->snapshot_item(0);
    my $node_type = $element->get_node_type;
    if ($node_type != DOM_TYPE_ELEMENT and $node_type != DOM_TYPE_DOCUMENT) {
        print "Can't handle node type $node_type\n";
        return;
    }

    return $element;
}


# Get the offsets of the given element
sub get_offsets {
    my ($element) = @_;

    my ($width, $height) = ($element->get_offset_width, $element->get_offset_height);
    my ($left, $top) =  ($element->get_offset_left, $element->get_offset_top);

    while ($element = $element->get_offset_parent) {
        $left += $element->get_offset_left - $element->get_scroll_left + $element->get_client_left;
        $top  += $element->get_offset_top - $element->get_scroll_top + $element->get_client_top;
    }

    return ($left, $top, $width, $height);
}


exit main() unless caller;
