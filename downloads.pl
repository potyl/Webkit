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

	my $session = Gtk2::WebKit::WebView->webkit_get_default_session();
    $session->signal_connect('request-started' => \&tracker_cb);

    my $view = Gtk2::WebKit::WebView->new();

    # Track all downloads
    $view->signal_connect('notify::load-status' => \&load_status_cb);

    $window->add($view);
    $window->show_all();

    $view->load_uri($url);

    Gtk2->main();
    return 0;
}


sub tracker_cb {
    my ($session, $message, $socket) = @_;

    ++$TOTAL;

	my $uri = "Resource $TOTAL";
    my $start = time;
    $message->signal_connect("finished" => sub {
        printf "Downloaded %s in %.2f seconds\n", $uri, time - $start;
    });

    return;
}


sub load_status_cb {
    my ($view) = @_;
    my $uri = $view->get_uri or return;
    return unless $view->get_load_status eq 'finished';

    my $frame = $view->get_main_frame;
    my $data_source = $frame->get_data_source;
    return if $data_source->is_loading;

    my $total = 0;
    my $size = 0;
    my $main_resource = $data_source->get_main_resource;
    $size = length($main_resource->get_data // '');
    $total += $size;
    printf "%s %d bytes; %s\n", $main_resource->get_uri, $size, $main_resource->get_mime_type // '';

    foreach my $sub_resource ($data_source->get_subresources) {
        $size = length($sub_resource->get_data // '');
        $total += $size;
        printf "%s %d bytes; %s\n", $sub_resource->get_uri, $size, $sub_resource->get_mime_type // '';
    }

    print "Downlodaded $TOTAL resources with $total bytes\n";
    Gtk2->main_quit();
}


exit main() unless caller;
