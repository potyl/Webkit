#!/usr/bin/env perl

=head1 NAME

har.pl - Generate a HTTP Archive Specification

=head1 SYNOPSIS

Simple usage:

    har.pl http://www.google.com/ 

=head1 DESCRIPTION

Generates a HTTP Archive Specification for the given URL.

=cut

use strict;
use warnings;

use Glib ':constants';
use Gtk3 -init;
use Gtk3::WebKit;
use HTTP::Soup;
use Data::Dumper;
use Time::HiRes qw(time);
use POSIX qw(strftime);

sub main {
    my ($url) = @ARGV;
    $url ||= 'http://localhost:3001/';

    my $view = Gtk3::WebKit::WebView->new();

    my $har = {
        version => '1.2',
        creator => {
            name    => 'har.pl',
            version => '1.0',
        },
        browser => {
            name    => 'HAR', #$view->get_settings->get_user_agent
            version => '1.0',
        },
        pages   => [
            {
                startedDateTime => undef, # to be defined later
                id              => 'main_page',
                title           => undef, # to be defined later
                pageTimings     => {
                    onContentLoad => -1,
                    onLoad        => -1,
                },
            },
        ],
        entries => [],
        comment => '',
    };

    # Track all downloads
    my $session = Gtk3::WebKit->get_default_session();
    $session->signal_connect('request-started' => \&tracker_cb, $har);

    # Track once all downloads are finished
    $view->signal_connect('notify::load-status' => \&load_status_cb, $har);
    $view->load_uri($url);

    my $start = time();
    Gtk3->main();
    $har->{pages}[0]{startedDateTime} = get_iso_8601_time($start);
    print Dumper({ log => $har });

    return 0;
}


# Called when WebKit is about to download a new resource (document, page, image, etc).
sub tracker_cb {
    my ($session, $message, $socket, $har) = @_;
my $resources = {};
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

        my $headers = $message->get('response-headers');
        $headers->foreach(sub {
            my ($name, $value) = @_;
            print "Header: $name => $value\n";
        });
    });

    return;
}


# Called when webkit updates it's 'load-status'.
sub load_status_cb {
    my ($view, undef, $har) = @_;
print Dumper(\@_);
my $resources = {};
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

    Gtk3::main_quit();
}


sub get_iso_8601_time {
    my ($time) = @_;
    my ($epoch, $fraction) = split /[.]/, $time;

    # We need to munge the timezone indicator to add a colon between the hour and minute part
    my $tz = strftime "%z", localtime $epoch;
    $tz =~ s/([0-9]{2})([0-9]{2})/$1:$2/;

    return strftime "%Y-%m-%dT%H:%M:%S.$fraction$tz", localtime $epoch;
}

exit main() unless caller;
