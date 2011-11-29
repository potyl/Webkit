#!/usr/bin/env perl

=head1 NAME

screenshot.pl - Take a screenshot

=head1 SYNOPSIS

screenshot.pl [OPTION]... URI

        --pause MS           number of miliseconds to wait before taking a screenshot
        --show               show the window where the screenshots are taken from
    -x, --xpath XPATH        XPath expression of the element to screenshot
    -t, --type TYPE          format type (svg, ps, pdf, png)
    -o, --output FILE        the screenshot's file name
    -s, --size SIZE          the window's size (ex: 1024x800)
    -u, --user USER          the user name to use
    -p, --password PASSWORD  the password to use
        --transparent        if true then the window will be transparent
    -h, --help               print this help message

Simple usage:

Save a page as an SVG:

    screenshot.pl --type svg http://www.google.com/

Save a page as a PDF:

    screenshot.pl --output cpan.pdf http://search.cpan.org/

Save an element of a page taken from an XPath query as a PNG:

    screenshot.pl --output ba.png --xpath 'id("content")' http://bratislava.pm.org/

=head1 DESCRIPTION

Take a screenshot of a page or part of a page by specifying an XPath query.

=cut

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long qw(:config auto_help);
use Pod::Usage;

use Glib ':constants';
use Gtk3 -init;
use Gtk3::WebKit;
use Cairo::GObject;

use constant DOM_TYPE_ELEMENT => 1;
use constant DOM_TYPE_DOCUMENT => 9;
use constant ORDERED_NODE_SNAPSHOT_TYPE => 7;

my %TYPES = (
    svg => sub { save_as_vector('Cairo::SvgSurface', @_) },
    ps  => sub { save_as_vector('Cairo::PsSurface', @_) },
    pdf => sub { save_as_vector('Cairo::PdfSurface', @_) },
    png => \&save_as_png,
);

sub main {
    GetOptions(
        'pause=i'      => \my $pause,
        'show'         => \my $show,
        'o|output=s'   => \my $filename,
        's|size=s'     => \my $geometry,
        'u|user=s'     => \my $user,
        'x|xpath=s'    => \my $xpath,
        'p|password=s' => \my $password,
        't|type=s'     => \my $type,
        'transparent'  => \my $transparent,
    ) or pod2usage(1);
    my ($url) = @ARGV or pod2usage(1);

    if ($type) {
        $type = lc $type;
        die "Type must be one of: ", join(", ", keys %TYPES) unless exists $TYPES{$type};
    }
    elsif (defined $filename) {
        if ( ($type) = ($filename =~ /\.([^.]+)$/) ) {
            $type = lc $type;
            die "Extension must be one of: ", join(", ", keys %TYPES) unless exists $TYPES{$type};
        }
        else {
            $type = 'pdf';
            $filename .= ".$type";
        }
    }
    else {
        $type = 'pdf';
    }
    $filename ||= "screenshot.$type";


    if (defined $user and defined $password) {
        require HTTP::Soup;

        # Remove the default authentication dialog so that we can provide our
        # own authentication method.
        my $session = Gtk3::WebKit->get_default_session();
        $session->remove_feature_by_type('Gtk3::WebKit::SoupAuthDialog');

        my $count = 0;
        $session->signal_connect('authenticate' => sub {
            my ($session, $message, $auth) = @_;
            if ($count++) {
                print "Too many authentication failures\n";
                Gtk3->main_quit();
            }
            $auth->authenticate($user, $password);
        });
    }


    my $save_as_func = $TYPES{$type};

    my $view = Gtk3::WebKit::WebView->new();
    $view->signal_connect('notify::load-status' => sub {
        return unless $view->get_uri and ($view->get_load_status eq 'finished');

        # Sometimes the program dies with:
        #  (<unknown>:19092): Gtk-CRITICAL **: gtk_widget_draw: assertion `!widget->priv->alloc_needed' failed
        # This seem to happend is there's a newtwork error and we can't download
        # external stuff (e.g. facebook iframe). This timeout seems to help a bit.
        my $grab_screenshot_cb = sub {
            grab_screenshot($view, $filename, $save_as_func, $xpath);
        };
        if ($pause) {
            Glib::Timeout->add($pause, $grab_screenshot_cb);
        }
        else {
            Glib::Idle->add($grab_screenshot_cb);
        }
    });
    $view->load_uri($url);


    my $window = $show ? Gtk3::Window->new('toplevel') : Gtk3::OffscreenWindow->new();
    if (defined $geometry and $geometry =~ /^ ([0-9]+) x ([0-9]+) $/x) {
        my ($width, $height) = ($1, $2);
        $window->set_default_size($width, $height);
    }

    # Set the main window transparent
    if ($transparent) {
        my $screen = $window->get_screen;
        $window->set_visual($screen->get_rgba_visual || $screen->get_system_visual);
        $view->set_transparent(TRUE);
    }

    $window->add($view);
    $window->show_all();

    Gtk3->main();
    return 0;
}


sub grab_screenshot {
    my ($view, $filename, $save_as_func, $xpath) = @_;

    my ($left, $top, $width, $height) = (0, 0, 0, 0);
    if (defined $xpath) {
        # Get the first element returned by the XPath query and return it's offsets
        my $element = get_xpath_element($view->get_dom_document, $xpath);
        ($left, $top, $width, $height) = get_offsets($element) if $element;
    }
    if (!$width and !$height) {
        ($width, $height) = ($view->get_allocated_width, $view->get_allocated_height);
    }

    $save_as_func->($view, $filename, $left, $top, $width, $height);
    print "$filename has size: $width x $height\n";

    Gtk3->main_quit();
}


sub save_as_vector {
    my ($surface_class, $widget, $filename, $left, $top, $width, $height) = @_;
    my $surface = $surface_class->create($filename, $width, $height);
    my $cr = Cairo::Context->create($surface);
    $cr->translate(-$left, -$top);
    $widget->draw($cr);
}


sub save_as_png {
    my ($widget, $filename, $left, $top, $width, $height) = @_;
    my $surface = Cairo::ImageSurface->create(argb32 => $width, $height);
    my $cr = Cairo::Context->create($surface);
    $cr->translate(-$left, -$top);
    $widget->draw($cr);
    $surface->write_to_png($filename);
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

    $element = $element->get('body') if $element->isa('Gtk3::WebKit::DOMDocument');
    my ($width, $height) = ($element->get_offset_width, $element->get_offset_height);
    my ($left, $top) =  ($element->get_offset_left, $element->get_offset_top);

    while ($element = $element->get_offset_parent) {
        $left += $element->get_offset_left - $element->get_scroll_left + $element->get_client_left;
        $top  += $element->get_offset_top - $element->get_scroll_top + $element->get_client_top;
    }

    return ($left, $top, $width, $height);
}

exit main() unless caller;
