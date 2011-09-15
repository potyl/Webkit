#!/usr/bin/env perl

use strict;
use warnings;
use Glib::Object::Introspection;

Glib::Object::Introspection->setup(
  basename => 'Gtk',
  version => '2.0',
  package => 'Gtk2');

Glib::Object::Introspection->setup(
  basename => 'WebKit',
  version => '1.0',
  package => 'Gtk2::WebKit');

Gtk2::init();

my $view = Gtk2::WebKit::WebView->new;

my $sw = Gtk2::ScrolledWindow->new;
$sw->add($view);

my $win = Gtk2::Window->new ('toplevel');
$win->set_default_size(800, 600);
$win->signal_connect(destroy => sub { Gtk2->main_quit });
$win->add($sw);
$win->show_all;

$view->load_uri( $ARGV[0] // 'http://perldition.org' );

Gtk2->main;
