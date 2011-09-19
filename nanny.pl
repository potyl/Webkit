#!/usr/bin/env perl

=head1 NAME

nanny.pl - Limit the websites that can be browsed

=head1 SYNOPSIS

nanny.pl [URI]

    -h, --help    print this help message
    -s, --super   use "super" mode and block all resources (js & css)

Simple usage:

    nanny.pl http://www.google.com/

=head1 DESCRIPTION

Don't let the user escape from the current site. This is a very basic parental
control implementation.

=cut

use strict;
use warnings;

use Glib ':constants';
use Gtk3 -init;
use Gtk3::WebKit;
use Getopt::Long qw(:config auto_help);
use Pod::Usage;
use Data::Dumper;
use URI;


sub main {
    GetOptions(
        's|super' => \my $super,
    ) or podusage(1);
    my ($url) = @ARGV;
    $url ||= 'http://localhost:3001/';
    my $allowed_host_port = get_host_port($url);

    my $window = Gtk3::Window->new('toplevel');
    $window->set_default_size(800, 600);
    $window->signal_connect(destroy => sub { Gtk3->main_quit() });

    my $view = Gtk3::WebKit::WebView->new();

    if ($super) {
        print "Super nanny activated\n";
        $view->signal_connect("resource-request-starting" => sub {
            my ($view, $frame, $resource, $request, $response) = @_;

            my $host_port = get_host_port($request->get_uri);
            return if $host_port eq $allowed_host_port;

            # Block the request if it goes outside, we block by setting the URI
            # to 'about:blank'
            print "Block access to $host_port\n";
            $request->set_uri('about:blank');
        });
    }
    else {
        print "Nanny activated\n";
        # Add a callback to monitor where each URI will go and reject the URI if the
        # location differs from the original website.
        # This only blocks, iframes and clicked links. Javascript and CSS are not blocked.
        $view->signal_connect("navigation-policy-decision-requested" => sub {
            my ($view, $frame, $request, $action, $decision) = @_;

            my $host_port = get_host_port($request->get_uri);

            # We allow browsing the same site
            return FALSE if $host_port eq $allowed_host_port;

            # We block the access to an external site
            print "Block access to $host_port\n";
            $decision->ignore();
            return TRUE;
        });
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


sub get_host_port {
    my ($url) = @_;
    my $uri = URI->new($url);
    # Not all URI have a host/port (e.g. "mailto:me@example.com")
    return $uri->can('host_port') ? $uri->host_port : ''; 
}

exit main() unless caller;
