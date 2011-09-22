#!/usr/bin/env perl

=head1 NAME

transparent.pl - Load a page with a transparent background

=head1 SYNOPSIS

transparent.pl file://$PWD/sample.html

=head1 DESCRIPTION

Loads an URI and displays the page in a transparent window. The page must use
the following CSS rule:

    body {
        background-color: rgba(0,0,0,0);
    }

=cut

use strict;
use warnings;

use Glib ':constants';
use Gtk3 -init;
use Gtk3::WebKit;
use Data::Dumper;

use Glib::Object::Introspection;
Glib::Object::Introspection->setup(
        basename => 'Gdk',
        version  => '3.0',
        package  => 'Gdk',
);


sub main {
    my ($url) = @ARGV;
    $url ||= 'http://localhost:3001/';

    my $window = Gtk3::Window->new('toplevel');

    # Set the main window transparent
    my $screen = $window->get_screen;
    $window->set_visual($screen->get_rgba_visual || $screen->get_system_visual);

    $window->set_default_size(800, 600);
    $window->signal_connect(destroy => sub { Gtk3->main_quit() });
    $window->set_decorated(FALSE);

    my $view = Gtk3::WebKit::WebView->new();
    $view->set_transparent(TRUE);

    # Pack the widgets together
    $window->add($view);
    $window->show_all();

    $view->load_uri($url);
    $view->grab_focus();

    Gtk3->main();
    return 0;
}


exit main() unless caller;
