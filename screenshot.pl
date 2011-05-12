#!/usr/bin/env perl

=head1 NAME

screenshot.pl - Take a screenshot of a page

=head1 SYNOPSIS

Simple usage:

    screenshot.pl http://www.google.com/ pic.png

Or without showing a window

    xvfb-run --server-args="-screen 0 1024x768x24" screenshot.pl http://www.google.com/ pic.png

=head1 DESCRIPTION

Loads an URI and takes a screeshot once the page is rendered.

=cut

use strict;
use warnings;

use Glib qw(TRUE FALSE);
use Gtk2 -init;
use Gtk2::WebKit;
use Data::Dumper;


sub main {
    die "Usage: url file\n" unless @ARGV == 2;
    my ($url, $file) = @ARGV;

    my $window = Gtk2::Window->new('toplevel');
    $window->set_default_size(800, 600);
    $window->signal_connect(destroy => sub { Gtk2->main_quit() });

    my $view = Gtk2::WebKit::WebView->new();
    my $button = Gtk2::Button->new("Capture");

    # Take a screenshot once all is loaded
    $view->signal_connect('notify::load-status' => \&load_status_cb, $file);


    $window->add($view);
    $window->show_all();

    $view->load_uri($url);

    Gtk2->main();
    return 0;
}


sub load_status_cb {
    my ($view, undef, $file) = @_;
    my $uri = $view->get_uri or return;
    return unless $view->get_load_status eq 'finished';

    my $pixmap = $view->get_snapshot();
    if (! $pixmap) {
        warn "Can't get a snapshot from webkit";
        return;
    }

    my $allocation = $view->allocation;
    my ($width, $height) = ($allocation->width, $allocation->height);

    my $pixbuf = Gtk2::Gdk::Pixbuf->get_from_drawable($pixmap, undef, 0, 0, 0, 0, $width, $height);
    if (! $pixbuf) {
        warn "Can't get a pixbuf from the drawable";
        return;
    }
    $pixbuf->save($file, 'png');
    print "Screenshot saved as $file\n";

    Gtk2->main_quit();
}


exit main() unless caller;
