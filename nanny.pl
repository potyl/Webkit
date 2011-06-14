#!/usr/bin/env perl

=head1 NAME

nanny.pl - Limit the websites that can be browsed

=head1 SYNOPSIS

Simple usage:

    nanny.pl http://www.google.com/

=head1 DESCRIPTION

Don't let the user escape from the current site. This is a very basic parental
control implementation.

=cut

use strict;
use warnings;

use Glib qw(TRUE FALSE);
use Gtk2 -init;
use WWW::WebKit;
use Data::Dumper;
use URI;


sub main {
    my ($url) = @ARGV;
    $url ||= 'http://localhost:3001/';
    my $allowed_host_port = get_host_port($url);

    my $window = Gtk2::Window->new('toplevel');
    $window->set_default_size(800, 600);
    $window->signal_connect(destroy => sub { Gtk2->main_quit() });

    my $view = WWW::WebKit::WebView->new();
    
    # Add a callback to monitor where each URI will go and reject the URI if the
    # location differs from the original website.
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

    # Pack the widgets together
    my $scrolls = Gtk2::ScrolledWindow->new();
    $scrolls->add($view);

    $window->add($scrolls);
    $window->show_all();

    $view->load_uri($url);

    Gtk2->main;
    return 0;
}


sub get_host_port {
    my ($url) = @_;
    my $uri = URI->new($url);
    # Not all URI have a host/port (e.g. "mailto:me@example.com")
    return $uri->can('host_port') ? $uri->host_port : ''; 
}

exit main() unless caller;
