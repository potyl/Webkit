#!/usr/bin/env perl

=head1 NAME

webkit.pl - Embed a webkit widget in an application

=head1 SYNOPSIS

webkit.pl [OPTION]... [URI]

    -h, --help           print this help message
    -u, --user-agent UA  the user agent to use

Simple usage:

    webkit.pl http://www.google.com/

=head1 DESCRIPTION

Display a web page.

=cut

use strict;
use warnings;

use Glib ':constants';
use Gtk3 -init;
use Gtk3::WebKit;
use Data::Dumper;


sub main {
    GetOptions(
        'u|user-agent=s' => \my $user_agent,
    ) or pod2usage(1);
    my ($url) = @ARGV;
    $url ||= 'http://localhost:3001/';

    my $window = Gtk3::Window->new('toplevel');
    $window->set_default_size(800, 600);
    $window->signal_connect(destroy => sub { Gtk3->main_quit() });


    my $view = Gtk3::WebKit::WebView->new();

    if ($user_agent) {
        my $settings = $view->get_settings;
        $settings->set('user-agent', $user_agent);
    }

    # Pack the widgets together
    my $scrolls = Gtk3::ScrolledWindow->new();
    $scrolls->add($view);


    $window->add($scrolls);
    $window->show_all();

    $view->load_uri($url);

    Gtk3->main;
    return 0;
}


exit main() unless caller;
