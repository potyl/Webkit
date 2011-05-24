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

	my $loop = Glib::MainLoop->new();

    # Track all downloads
	my $session = Gtk2::WebKit->get_default_session();
    my %resources;
    $session->signal_connect('request-started' => \&tracker_cb, \%resources);

    my $view = Gtk2::WebKit::WebView->new();

	# Track once all downloads are finished
    $view->signal_connect('notify::load-status' => \&load_status_cb, [ $loop, \%resources ]);

    $view->load_uri($url);
    $loop->run();

    return 0;
}


sub tracker_cb {
    my ($session, $message, $socket, $resources) = @_;
    ++$TOTAL;

    my $uri = $message->get_uri->to_string;
    my $start = time;
    $resources->{$uri}{start} = time;
    $resources->{$uri}{uri} = $uri;
    $message->signal_connect("finished" => sub {
        my $end = $resources->{$uri}{end} = time;
        my $elapsed = $resources->{$uri}{elapsed} = $end - $start;
#        printf "Downloaded %s in %.2f seconds\n", $uri, $elapsed;
    });

    return;
}


sub load_status_cb {
    my ($loop, $resources) = @{ pop @_ };
    my ($view) = @_;

    my $uri = $view->get_uri or return;
    return unless $view->get_load_status eq 'finished';

    my $frame = $view->get_main_frame;
    my $data_source = $frame->get_data_source;
    return if $data_source->is_loading;

    my $bytes = 0;
    foreach my $resource ($data_source->get_main_resource, $data_source->get_subresources) {
        my $uri = $resource->get_uri;
        my $data = $resources->{$uri};
        my $time;
        if (! $data) {
            print "Can't find data for $uri\n";
            $time = "???";
        }
        else {
            $time = $resources->{$uri}{elapsed};
            $time = defined $time ? sprintf "%.2f", $time : 'undef';
        }
        my $size = length($resource->get_data // '');
        $bytes += $size;
        printf "%s %d bytes; %s in %s sec\n", $uri, $size, $resource->get_mime_type // 'No mime-type', $time;
    }

    print "Downlodaded $TOTAL resources with $bytes bytes\n";
    $loop->quit();
}


exit main() unless caller;
