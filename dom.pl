#!/usr/bin/env perl

=head1 NAME

dom.pl - DOM manipulation

=head1 SYNOPSIS

Simple usage:

    dom.pl http://search.cpan.org/ 

=head1 DESCRIPTION

Get the DOM of the current document.

=cut

use strict;
use warnings;


use Glib::Object::Introspection;
use Gtk3;

Glib::Object::Introspection->setup(
  basename => 'WebKit',
  version  => '3.0',
  package  => 'WWW::WebKit'
);
use Glib ':constants';
use Data::Dumper;

sub main {
    my ($url) = @ARGV;
    $url ||= 'http://localhost:3001/';

    Gtk3::init();
    my $loop = Glib::MainLoop->new();

    my $view = WWW::WebKit::WebView->new();

    # Track once all downloads are finished
    $view->signal_connect('notify::load-status' => \&load_status_cb, $loop);
    $view->signal_connect('console-message' => sub { TRUE });

    $view->load_uri($url);
    $loop->run();

    return 0;
}


# Called when webkit updates it's 'load-status'.
sub load_status_cb {
    my ($view, undef, $loop) = @_;

    my $uri = $view->get_uri or return;
    return unless $view->get_load_status eq 'finished';
    $loop->quit();

    my $document = $view->get_dom_document();
    #$document->get_body();
    print "document is $document\n";
    print $document->get_document_uri, "\n";
    print "Ready state: ", $document->get_ready_state(), "\n";

    my $body = $document->get('body');
    print Dumper($body->get('id'));

#    printf "Heap limit: %s\n", WWW::WebKit::DOMMemoryInfo->get_js_heap_size_limit();
#    printf "Total peap size: %s\n", WWW::WebKit::DOMMemoryInfo->get_total_js_heap_size();
#    printf "Used heap size: %s\n", WWW::WebKit::DOMMemoryInfo->get_used_js_heap_size();
}


exit main() unless caller;
