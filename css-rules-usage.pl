#!/usr/bin/env perl

=head1 NAME

css-rules-usage.pl - Reports the usage of CSS rules

=head1 SYNOPSIS

dom.pl [OPTION]... [URI]

    -d, --debug            turn on debug mode
    -v, --verbose          turn on verbose mode
        --exit             quit with exit instead of stopping the main loop
    -h, --help             print this help message

Simple usage:

    css-rules-usage.pl http://www.google.com/

=head1 DESCRIPTION

This script matches the CSS rules defines against each element and reports the
usage of each CSS rule.

=cut

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long qw(:config auto_help);
use Pod::Usage;

use Glib ':constants';
use Gtk3;
use Gtk3::WebKit search_path => '/usr/local/lib/girepository-1.0';
use HTTP::Soup;

use CSS::DOM;
use URI;

use constant DOM_TYPE_ELEMENT => 1;
use constant ORDERED_NODE_SNAPSHOT_TYPE => 7;


my $DEBUG = 0;
my $VERBOSE = 0;


sub main {
    Gtk3::init();

    GetOptions(
        'save|s'    => \my $save,
        'debug|d'   => \$DEBUG,
        'verbose|v' => \$VERBOSE,
        'exit'      => \my $do_exit,
    ) or podusage(1);

    my ($url) = @ARGV;
    $url ||= 'http://localhost:3001/';

    my $view = Gtk3::WebKit::WebView->new();

    my $session = Gtk3::WebKit->get_default_session();
    my %resources;
    $session->signal_connect('request-started' => sub {
        my ($session, $message, $socket) = @_;
        my $uri = $message->get_uri->to_string(FALSE);
        $resources{$uri} = "";
        $message->signal_connect("finished" => sub {
            my ($message) = @_;
            # response-headers->get_content_type({}) issues a warning about: Use of uninitialized value in subroutine entry
            #my ($content_type) = $message->get('response-headers')->get_content_type({}) || '';
            my $content_type = $message->get('response-headers')->get_one('content-type') || '';
            $content_type =~ s/\s*;.*$//;
            delete $resources{$uri} if $content_type ne 'text/css';
        });

        # NOTE ideally calling $message->get('reponse-body')->data in the
        # 'finished' signal would get us the data, but the body is always of
        # length 0! Maybe another 'finished' signal truncates the body?
        #
        # In order to get the content we need accumulate the chunks by hand.

        # TODO detect the mime-type based on the headers and skip the chunking
        # of mime-types that are not text/css.
        $message->signal_connect('got-chunk' => sub {
            my ($message, $chunk) = @_;
            $resources{$uri} .= $chunk->data;
        });
    });


    $view->signal_connect('notify::load-status' => sub {
        return unless $view->get_uri and ($view->get_load_status eq 'finished');
        print "Document loaded\n";

        if ($save) {
            my $file = 'page.html';
            open my $handle, '>:encoding(UTF-8)', $file or die "Can't write to $file: $!";
            print $handle $view->get_focused_frame->get_data_source->get_data->{str};
            close $handle;
        }

        report_selectors_usage($view->get_dom_document, \%resources);
        if ($do_exit) {
            # Prevents the seg fault at the cleanup in an unstable WebKit version
            exit 0;
        }
        else {
            Gtk3->main_quit();
        }
    });
    $view->load_uri($url);

    my $window = Gtk3::OffscreenWindow->new();
    $window->add($view);
    $window->show_all();

    Gtk3->main();
    return 0;
}


sub report_selectors_usage {
    my ($doc, $resources) = @_;

    # Get the RAW defition of the CSS (need to parse CSS text in order to extract the rules)
    my %selectors;
    my $resolver = $doc->create_ns_resolver($doc);
    my $xpath_results = $doc->evaluate('//style | //link[@rel = "stylesheet" and @type="text/css" and @href]', $doc, $resolver, ORDERED_NODE_SNAPSHOT_TYPE, undef);
    my $length = $xpath_results->get_snapshot_length;
    for (my $i = 0; $i < $length; ++$i) {
        my $element = $xpath_results->snapshot_item($i);

        my $css_content;
        if ($element->get_tag_name eq 'STYLE') {
            $css_content = $element->get_first_child->get_text_content;
        }
        else {
            my $href = $element->get_attribute('href');
            my $url = URI->new_abs($href, $doc->get('url'))->as_string;
            $css_content = $resources->{$url};
            if (!$css_content) {
                print "*** Missing content for $url\n";
                print Dumper([ keys %$resources ]);
                next;
            }
        }

        my $css = CSS::DOM::parse($css_content);
        my $rules = 0;
        foreach my $rule ($css->cssRules) {
            ++$rules;
            if ($rule->isa('CSS::DOM::Rule')) {
                foreach my $selectorText (split /\s*,\s*/, $rule->selectorText) {
                    $selectors{$selectorText} = {
                        count    => 0,
                        selector => $selectorText,
                        rule     => $rule,
                    };
                }
            }
            else {
                #FIXME implement other rules (@media, @import)
                print "Skipping CSS entry $rule\n";
                next;
            }
        }
        print "Loaded $rules rules\n";
    }
    printf "Found %d selectors\n", scalar(keys %selectors);
    walk_dom($doc->get_body, \%selectors);

    my @selectors = sort {
           $b->{count} <=> $a->{count}
        || $a->{selector} cmp $b->{selector}
    } values %selectors;

    my $unused = 0;
    foreach my $selector (@selectors) {
        my $count = $selector->{count};
        printf "Selector %s is used %d times\n", $selector->{selector}, $count if $VERBOSE or $count == 0;
        ++$unused if $count == 0;
    }
    print "Found $unused unused selectors\n";
}


sub walk_dom {
    my ($node, $selectors) = @_;

    if ($node->get_node_type == DOM_TYPE_ELEMENT) {
        foreach my $selector (keys %$selectors) {
            my $matches = $node->webkit_matches_selector($selector);
            ++$selectors->{$selector}{count} if $matches;
            printf "Element %s matches %s? %s\n", $node->get_tag_name, $selector, $matches ? 'TRUE' : 'FALSE' if $DEBUG;
        }
    }

    my $child_nodes = $node->get_child_nodes;
    for (my ($i, $l) = (0, $child_nodes->get_length); $i < $l; ++$i) {
        my $child = $child_nodes->item($i);
        walk_dom($child, $selectors);
    }
}


exit main() unless caller;
