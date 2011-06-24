#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;

use Glib::Object::Introspection;

Glib::Object::Introspection->setup(
  basename => 'Gtk',
  version  => '3.0',
  package  => 'Gtk3'
);

Glib::Object::Introspection->setup(
  basename => 'WebKit',
  version  => '3.0',
  package  => 'WebKit'
);
use Cairo::GObject;

Gtk3::init(0, []);
my ($url) = @ARGV;
$url ||= 'http://localhost:3001/';

my $view = WebKit::WebView->new();
$view->signal_connect('notify::load-status' => sub {
    return unless $view->get_uri and ($view->get_load_status eq 'finished');

#    my $allocation = $view->get_allocation;
#    my ($width, $height) = ($allocation->{width}, $allocation->{height});
    my ($width, $height) = ($view->get_allocated_width, $view->get_allocated_height);
    print "size = $width x $height\n";
    my $surface = Cairo::PdfSurface->create("a.pdf", 1.0 * $width, 1.0 * $height);
    my $cr = Cairo::Context->create($surface);
    $view->draw($cr);
});
$view->load_uri($url);


my $win = Gtk3::OffscreenWindow->new();
$win->add($view);
$win->show_all();


Gtk3->main();
