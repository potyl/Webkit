#!/usr/bin/env perl

=head1 NAME

downloads.pl - Track the download of each resource

=head1 SYNOPSIS

Simple usage:

    downloads.pl http://www.google.com/ 

=head1 DESCRIPTION

Tracks the downloads for one url.

=cut

use strict;
use warnings;

use Glib qw(TRUE FALSE);
use Gtk2 -init;
use Gtk2::WebKit;
use Data::Dumper;
use Time::HiRes qw(time);

my $TOTAL = 0;

sub main {
    die "Usage: url\n" unless @ARGV;
    my ($url) = @ARGV;

    my $window = Gtk2::Window->new('toplevel');
    $window->set_default_size(800, 600);
    $window->signal_connect(destroy => sub { Gtk2->main_quit() });

    my $view = Gtk2::WebKit::WebView->new();
    my $button = Gtk2::Button->new("Capture");

    # Track all downloads
    $view->signal_connect('resource-request-starting' => \&tracker_cb);
    $view->signal_connect('notify::load-status' => \&load_status_cb);

    $window->add($view);
    $window->show_all();

    $view->load_uri($url);

    Gtk2->main();
    return 0;
}


sub tracker_cb {
    my ($view, $frame, $resource, $request, $response) = @_;

    my $uri = $request->get_uri;

    return if $uri eq 'about:blank';
    print "Resource $uri\n";
    ++$TOTAL;
    
    return;
    
    # This doesn't work :(

    my $message = $request->get_message;
    if (! $message) {
        print "Can't get message for $uri\n";
        return FALSE; 
    }

    my $start = time;
    $message->signal_connect("got-headers" => sub {
        printf "Downloaded %s in %.2f seconds\n", $uri, time - $start;
    });
    $message->signal_connect("notify::reason-phrase", sub {
        print "Change!!!\n";
    });

    return;
}


sub load_status_cb {
    my ($view) = @_;
    my $uri = $view->get_uri or return;
    return unless $view->get_load_status eq 'finished';

    print "Downlodaded $TOTAL resources\n";
    Gtk2->main_quit();
}


exit main() unless caller;
