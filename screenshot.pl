#!/usr/bin/env perl

use strict;
use warnings;

use Glib qw(TRUE FALSE);
use Gtk2 -init;
use Gtk2::WebKit;
use Data::Dumper;

die "Usage: url file\n" unless @ARGV == 2;
my ($url, $file) = @ARGV;

my $view = Gtk2::WebKit::WebView->new;

my $sw = Gtk2::ScrolledWindow->new;
$sw->add($view);

my $win = Gtk2::Window->new;
$win->set_default_size(800, 600);
$win->signal_connect(destroy => sub { Gtk2->main_quit });

my $button = Gtk2::Button->new("Capture");
$button->signal_connect(clicked => \&save_as_png);

# Take a screenshot once all is loaded
$view->signal_connect("load-finished" => \&save_as_png);


my $box = Gtk2::VBox->new(0, 0);
$box->pack_start($button, FALSE, FALSE, 2);
$box->pack_start($sw, TRUE, TRUE, 2);


$win->add($box);
$win->show_all;

$view->open( $url );

Gtk2->main;


sub save_as_png {
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
    
    Gtk2->main_quit;
}
