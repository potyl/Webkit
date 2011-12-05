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
use JSON qw(to_json);
use POSIX qw(strftime);
use Time::HiRes qw(time);
use URI;
use URI::QueryParam;

# For debugging
$Data::Dumper::Pair = ' : ';
$Data::Dumper::Sortkeys = 1;

sub main {
    my ($url) = @ARGV;
    $url ||= 'http://localhost:3001/';

    my $view = Gtk3::WebKit::WebView->new();

    my %har = (
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
    );

    # Track all downloads
    my $session = Gtk3::WebKit->get_default_session();
    $session->signal_connect('request-started' => \&tracker_cb, \%har);

    # Track once all downloads are finished
    #$view->signal_connect('notify::load-status' => \&load_status_cb, $har);
    #$view->load_uri($url);




    my $l_button = Gtk3::Button->new("load");
    my $p_button = Gtk3::Button->new("print");

    # Execute the javascript when the user wants it
    $l_button->signal_connect(clicked => sub {

        %har = (
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
        );

        $har{pages}[0]{startedDateTime} = get_iso_8601_time(time);
        $view->load_uri($url);
    });

    $p_button->signal_connect(clicked => sub {
        my $log_har = { log => \%har };
        my $json = to_json(
            $log_har,
            # JSON configuration
            {
                utf8      => 1,
                pretty    => 1,
                canonical => 1,
            }
        );
        print $json;
    });


    # Pack the widgets together
    my $sw = Gtk3::ScrolledWindow->new();
    $sw->add($view);
    my $hbox = Gtk3::HBox->new(0, 0);
    $hbox->pack_start($p_button, TRUE, TRUE, 2);
    $hbox->pack_start($l_button, TRUE, TRUE, 2);

    my $box = Gtk3::VBox->new(0, 0);
    $box->pack_start($hbox, FALSE, FALSE, 2);
    $box->pack_start($sw, TRUE, TRUE, 2);


    my $window = Gtk3::Window->new('toplevel');
    $window->set_default_size(800, 600);
    $window->signal_connect(destroy => sub { Gtk3->main_quit() });

    $window->add($box);
    $window->show_all();



    Gtk3->main();

    return 0;
}


# Called when WebKit is about to download a new resource (document, page, image, etc).
sub tracker_cb {
    my ($session, $message, $socket, $har) = @_;

    my $start_time = time;
    my $har_entries = $har->{entries};
    my $har_entry = {
        pageref         => 'page_' . @$har_entries,
        startedDateTime => get_iso_8601_time($start_time),
        response        => {},
        cache           => {},
        timings         => {},
        # These fields have to be set once the connection is initialized ($message->get_address)
        #serverIPAddress => '10.0.0.1',
        #connection      => '52492',
    };
    push @$har_entries, $har_entry;

    my $soup_uri = $message->get_uri;
    my $uri = URI->new($soup_uri->to_string(FALSE));
    $message->signal_connect("finished" => sub {
        my $end_time = time;
        my $elapsed = $end_time - $start_time;
        $har_entry->{time} = int($elapsed * 1000); # As milliseconds

        $har_entry->{request}  = get_har_request($message);
        $har_entry->{response} = get_har_response($message);
    });

    return;
}


sub get_har_request {
    my ($message) = @_;

    my $soup_uri = $message->get_uri;
    my $uri = URI->new($soup_uri->to_string(FALSE));

    my $http_version = get_http_version($message);
    my $method = $message->get('method');

    # Caculate the header's size. Start of the headers "GET / HTTP/1.1\r\n"
    my $header_size = length($method) + 1 + length($uri->path_query) + 1 + length($http_version) + 2;

    # The request headers
    my $soup_headers = $message->get('request-headers');
    my @headers;
    my @cookies;
    $soup_headers->foreach(sub {
        my ($name, $value) = @_;
        push @headers, {
            name  => $name,
            value => $value,
        };

        # Add the header as "Name: value\r\n"
        $header_size += length($name) + 2 + length($value) + 2;

        if ($name eq 'Cookie') {
            push @cookies, get_cookies($value, $soup_uri);
        }
    });
    # Last "\r\n" marking the end of headers
    $header_size += 2;

    # Do we need to put the values encoded or decoded?
    # Also do we have to split ONLY at '&' ?
    my @query_string;
    foreach my $param ($uri->query_param) {
        foreach my $value ($uri->query_param($param)) {
            push @query_string, {
                name  => $param,
                value => $value,
            };
        }
    }

    # A request
    return {
        method      => $method,
        url         => $uri->as_string,
        httpVersion => $http_version,
        cookies     => \@cookies,
        headers     => \@headers,
        queryString => \@query_string,
        #postData    => {},
        headersSize => $header_size,
        bodySize    => $message->get('request-body')->length,
    };
}


sub get_har_response {
    my ($message) = @_;

    my $http_version = get_http_version($message);
    my $status       = $message->get('status-code');
    my $status_text  = $message->get('reason-phrase');

    # Caculate the header's size. Start of the headers "HTTP/1.1 301 Moved Permanently\r\n"
    my $header_size = length($http_version) + 1 + length($status) + 1 + length($status_text) + 2;

    # The request headers
    my $soup_headers = $message->get('response-headers');
    my @headers;
    my @cookies;
    my $redirect_url;
    my $soup_uri = $message->get_uri;
    $soup_headers->foreach(sub {
        my ($name, $value) = @_;
        push @headers, {
            name  => $name,
            value => $value,
        };

        # Add the header as "Name: value\r\n"
        $header_size += length($name) + 2 + length($value) + 2;

        if ($name eq 'Set-Cookie') {
            print "Set-Cookie: $value\n";
            push @cookies, get_cookies($value, $soup_uri);
        }
        elsif ($name eq 'Location') {
            # Should location be the exact value sent by the header or should it
            # be an absolute URL?
            $redirect_url = $value;
        }
    });
    # Last "\r\n" marking the end of headers
    $header_size += 2;


    return {
        status      => $status,
        statusText  => $status_text,
        httpVersion => $http_version,
        cookies     => \@cookies,
        headers     => \@headers,
        content     => {},
        redirectURL => $redirect_url,
        headersSize => $header_size,
        bodySize    => $status == 304 ? 0 : $message->get('response-body')->length,
    };
}


# Called when webkit updates it's 'load-status'.
sub load_status_cb {
    my ($view, undef, $har) = @_;

my $resources = {};
    my $uri = $view->get_uri or return;
    return unless $view->get_load_status eq 'finished';
    my $end = time;
    #FIXME wait until all resources are downloaded

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
#            print "Can't find data for $uri\n";
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
#        printf "%s %d bytes; %s (%s) in %s sec\n", $uri, $size, $mime, $status_code, $time;
    }

#    print "Quit\n";
#    Gtk3::main_quit();
#    $view->load_uri($ARGV[0]);
}


sub get_cookies {
    my ($raw, $uri) = @_;
    # FIXME can't parse cookies because of a GIR error: expected a blessed reference at /usr/local/lib/perl/5.12.4/Glib/Object/Introspection.pm line 57.
    my $cookie = HTTP::Soup::Cookie::parse($raw, $uri);

    my $har_cookie = {
        name     => $cookie->get_name,
        value    => $cookie->get_value,
        path     => $cookie->get_path,
        domain   => $cookie->get_domain,
        httpOnly => $cookie->get_http_only ? 1 : 0,
        secure   => $cookie->get_secure ? 1 : 0,
    };

    my $expires = $cookie->get_expires;
    $har_cookie->{expires} = $expires->to_string('iso8601-full') if defined $expires;

    $har_cookie;
}


sub get_iso_8601_time {
    my ($time) = @_;
    my ($epoch, $fraction) = split /[.]/, $time;

    # We need to munge the timezone indicator to add a colon between the hour and minute part
    my $tz = strftime "%z", localtime $epoch;
    $tz =~ s/([0-9]{2})([0-9]{2})/$1:$2/;

    return strftime "%Y-%m-%dT%H:%M:%S.$fraction$tz", localtime $epoch;
}


sub get_http_version {
    my ($message) = @_;

    # Transform 'http-1-1' into 'HTTP/1.1'
    my $http_version = uc $message->get_http_version;
    $http_version =~ s,^(HTTP)-([0-9])-([0-9]),$1/$2.$3,;
    return $http_version;
}


exit main() unless caller;
