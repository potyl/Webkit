#!/usr/bin/env perl

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
    my $screen = $window->get_screen;
    my $rgba = $screen->get_rgba_colormap;
    if ($rgba && $screen->is_composited) {
        print "Setting composited\n";
        Gtk2::Widget->set_default_colormap($rgba);
        $window->set_colormap($rgba);
    }

    $window->set_default_size(800, 600);
    $window->signal_connect(destroy => sub { Gtk2->main_quit() });
    $window->set_decorated(FALSE);


    my $view = Gtk2::WebKit::WebView->new;
    my $sw = Gtk2::ScrolledWindow->new;
    $sw->add($view);
    $view->set_transparent(TRUE);

    my $button = Gtk2::Button->new("Capture");
    $button->signal_connect(clicked => \&save_as_png, [$view, $file]);

    # Take a screenshot once all is loaded
    $view->signal_connect("load-finished" => \&save_as_png, [$view, $file]);


    my $box = Gtk2::VBox->new(0, 0);
    $box->pack_start($button, FALSE, FALSE, 2);
    $box->pack_start($sw, TRUE, TRUE, 2);


    $window->add($box);
    $window->show_all();

    $view->open($url);

    Gtk2->main;
    return 0;
}


sub save_as_png {
    my $data = pop;
    my ($view, $file) = @{ $data };

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


    my $status = $view->get_load_status;
    if ($status ne 'finished') {
        print "Warn: page not finished loading! (status: $status)\n";
    }
    else {
        print "Page finished loading\n";
    }

    Gtk2->main_quit();
}


exit main() unless caller;
