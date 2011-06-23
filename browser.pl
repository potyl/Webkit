#!/usr/bin/perl

use strict;
use warnings;

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
use Cairo;

Gtk3::init(0, []);
my ($url) = @ARGV;
$url ||= 'http://localhost:3001/';


my $view = WebKit::WebView->new();

my $scrolls = Gtk3::ScrolledWindow->new();
$scrolls->add($view);

my $win = Gtk3::Window->new ('toplevel');
$win->set_default_size(800, 600);
$win->signal_connect(destroy => sub { Gtk3->main_quit(); });
$win->add($scrolls);
$win->show_all();

$view->signal_connect('notify::load-status' => sub {
    my $uri = $view->get_uri or return;
    return unless $view->get_load_status eq 'finished';

    my ($width, $height) = ($view->get_allocated_width, $view->get_allocated_height);

    my $surface = Cairo::PdfSurface->create("a.pdf", 1.0 * $width, 1.0 * $height);
    my $cr = Cairo::Context->create($surface);
    $view->draw($cr);
});

$view->load_uri($url);

Gtk3->main();
