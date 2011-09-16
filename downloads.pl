#!/usr/bin/env perl

=head1 NAME

downloads.pl - Track the download of each resource

=head1 SYNOPSIS

Simple usage:

    downloads.pl http://www.google.com/ 

=head1 DESCRIPTION

Tracks all the downloads that are triggered for a starting page.

=cut

use strict;
use warnings;

use Glib ':constants';
use Gtk3 -init;
use WWW::WebKit;
use HTTP::Soup;
use Data::Dumper;
use Time::HiRes qw(time);

my $TOTAL = 0;
my $START;

sub main {
    my ($url) = @ARGV;
    $url ||= 'http://localhost:3001/';

    my $loop = Glib::MainLoop->new();

    # Track all downloads
    my $session = WWW::WebKit->get_default_session();
    my %resources;
    $session->signal_connect('request-started' => \&tracker_cb, \%resources);

    my $view = WWW::WebKit::WebView->new();

    # Track once all downloads are finished
    $view->signal_connect('notify::load-status' => \&load_status_cb, [ $loop, \%resources ]);

    $START = time;
    $view->load_uri($url);
    $loop->run();

    return 0;
}


# Called when WebKit is about to download a new resource (document, page, image, etc).
sub tracker_cb {
    my ($session, $message, $socket, $resources) = @_;
    ++$TOTAL;

    my $uri = $message->get_uri->to_string(FALSE);
    my $start = time;
    my $resource = $resources->{$uri} = {};
    $resource->{start} = time;
    $resource->{uri} = $uri;
    $message->signal_connect("finished" => sub {
        my $end = $resource->{end} = time;
        my $elapsed = $resource->{elapsed} = $end - $start;
        my $status_code = $resource->{status_code} = $message->get('status-code') // 'undef';
        #printf "Downloaded %s in %.2f seconds; code: %s\n", $uri, $elapsed, $status_code;
    });

#    $message->signal_connect('got-chunk' => sub {
#        print "Chunk @_\n";
#    });

    return;
}


# Called when webkit updates it's 'load-status'.
sub load_status_cb {
    my ($loop, $resources) = @{ pop @_ };
    my ($view) = @_;

    my $uri = $view->get_uri or return;
    return unless $view->get_load_status eq 'finished';
    my $end = time;

    my $frame = $view->get_main_frame;
    my $data_source = $frame->get_data_source;
    return if $data_source->is_loading;

    my $bytes = 0;
    foreach my $resource ($data_source->get_main_resource, @{ $data_source->get_subresources }) {
        my $uri = $resource->get_uri;
        next if $uri eq 'about:blank';

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
        my $mime = $resource->get_mime_type // 'No mime-type';
        my $status_code = $data->{status_code} // 'undef';
        printf "%s %d bytes; %s (%s) in %s sec\n", $uri, $size, $mime, $status_code, $time;
    }

    printf "Downlodaded $TOTAL resources with $bytes bytes in %.2f seconds\n", $end - $START;
    $loop->quit();
}


exit main() unless caller;
