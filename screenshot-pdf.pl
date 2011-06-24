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
use constant TRUE  => 1;
use constant FALSE => 0;

Gtk3::init(0, []);
my ($url, $filename) = @ARGV;
$url ||= 'http://localhost:3001/';
$filename ||= 'screenshot.pdf';

my $view = WebKit::WebView->new();
$view->signal_connect('notify::load-status' => sub {
    return unless $view->get_uri and ($view->get_load_status eq 'finished');

    printf "mapped? %s\n", $view->get_mapped ? 'YES' : 'NO';
    printf "visible? %s\n", $view->get_visible ? 'YES' : 'NO';
    printf "sensitive? %s\n", $view->is_sensitive ? 'YES' : 'NO';

    print "Is mapped!\n";
    # Sometimes the program dies with:
    #  (<unknown>:19092): Gtk-CRITICAL **: gtk_widget_draw: assertion `!widget->priv->alloc_needed' failed
    # This seem to happend is there's a newtwork error and we can't download
    # external stuff (e.g. facebook iframe). This timeout seems to help a bit.
    Glib::Timeout->add(1000, sub {
        save_as_pdf($view, $filename);
        Gtk3->main_quit();
    });
});
$view->load_uri($url);


# Grab a picture when ready
my $button = Gtk3::Button->new();
$button->set_label("Screenshot");
$button->signal_connect(clicked => sub {
    save_as_pdf($view, $filename);
    Gtk3->main_quit();
});

my $window = Gtk3::Window->new('toplevel');
$window->set_default_size(800, 600);
$window->signal_connect(destroy => sub { Gtk3->main_quit() });

my $box = Gtk3::VBox->new(0, 0);
$box->pack_start($button, TRUE, TRUE, 2);
$box->pack_start($view, TRUE, TRUE, 2);

$window->add($box);

$window->show_all();

Gtk3->main();


sub save_as_pdf {
    my ($widget, $filename) = @_;

#    my $allocation = $view->get_allocation;
#    my ($width, $height) = ($allocation->{width}, $allocation->{height});
    my ($width, $height) = ($widget->get_allocated_width, $widget->get_allocated_height);
    print "$filename has size: $width x $height\n";
    my $surface = Cairo::PdfSurface->create($filename, $width, $height);
    my $cr = Cairo::Context->create($surface);
    $view->draw($cr);
}
