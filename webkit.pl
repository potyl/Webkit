#!/usr/bin/env perl

=head1 NAME

webkit.pl - Embed a webkit widget in an application

=head1 SYNOPSIS

Simple usage:

    webkit.pl http://www.google.com/

=head1 DESCRIPTION

Display a web page.

=cut

use strict;
use warnings;

use Glib qw(TRUE FALSE);
use Gtk2 -init;
use Gtk2::WebKit;
use Data::Dumper;


sub main {
    die "Usage: url\n" unless @ARGV;
    my ($url) = @ARGV;

    my $window = Gtk2::Window->new('toplevel');
    $window->set_default_size(800, 600);
    $window->signal_connect(destroy => sub { Gtk2->main_quit() });


    my $view = Gtk2::WebKit::WebView->new();

    # Pack the widgets together
    my $scrolls = Gtk2::ScrolledWindow->new();
    $scrolls->add($view);


    $window->add($scrolls);
    $window->show_all();

    $view->open($url);

    Gtk2->main;
    return 0;
}


exit main() unless caller;
