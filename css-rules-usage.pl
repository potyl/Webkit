#!/usr/bin/env perl

=head1 NAME

css-rules-usage.pl - Reports the usage of CSS rules

=head1 SYNOPSIS

dom.pl [OPTION]... [URI]

    -d, --debug            turn on debug mode
    -v, --verbose          turn on verbose mode
        --exit             quit with exit instead of stopping the main loop
    -s, --save FILE        save the input file as FILE
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
use POSIX qw(_exit);

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
    my $requests_started = 0;
    my $requests_finished = 0;
    $session->signal_connect('request-started' => sub {
        my ($session, $message, $socket) = @_;
        ++$requests_started;
        $message->signal_connect("finished" => sub {
            my ($message) = @_;
            ++$requests_finished;
        });
    });


    $view->signal_connect('notify::load-status' => sub {
        return unless $view->get_uri and ($view->get_load_status eq 'finished');
        Glib::Idle->add(sub {
            # Wait until all CSS files are loaded
            return 1 unless $requests_started and $requests_started == $requests_finished;
            print "All resources are loaded ($requests_started/$requests_finished)\n";

            my $list = $view->get_focused_frame->get_data_source->get_subresources;
            my %resources;
            foreach my $resource (@$list) {
                my $data = $resource->get_data or next;
                my $uri = $resource->get_uri or next;
                $resources{$uri} = $data->{str};
            }

            if ($save) {
                my $file = 'page.html';
                open my $handle, '>:encoding(UTF-8)', $file or die "Can't write to $file: $!";
                print $handle $view->get_focused_frame->get_data_source->get_data->{str};
                close $handle;
            }

            report_selectors_usage($view->get_dom_document, \%resources);
            if ($do_exit) {
                # Prevents the seg fault at the cleanup in an unstable WebKit version
                _exit(0);
            }
            else {
                Gtk3->main_quit();
            }
        }) ;

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
    my $selectors = get_css_rules($doc, $resources);

    printf "Found %d selectors\n", scalar(keys %$selectors);
    walk_dom($doc->get_body, $selectors);

    my @selectors = sort {
           $b->{count} <=> $a->{count}
        || $a->{selector} cmp $b->{selector}
    } values %$selectors;

    my $unused = 0;
    foreach my $selector (@selectors) {
        my $count = $selector->{count};
        printf "Selector %s matches %d elements\n", $selector->{selector}, $count if $VERBOSE or $count == 0;
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


sub get_css_rules {
    my ($doc, $resources) = @_;

    my %selectors;

    # Get the RAW defition of the CSS (need to parse CSS text in order to extract the rules)
    my $resolver = $doc->create_ns_resolver($doc);
    my $xpath_results = $doc->evaluate('//style | //link[@rel = "stylesheet" and @type="text/css" and @href]', $doc, $resolver, ORDERED_NODE_SNAPSHOT_TYPE, undef);
    my $length = $xpath_results->get_snapshot_length;
    my $doc_url = $doc->get_document_uri;
    for (my $i = 0; $i < $length; ++$i) {
        my $element = $xpath_results->snapshot_item($i);

        my $css_content;
        my $base_url;
        if ($element->get_tag_name eq 'STYLE') {
            $base_url = $doc_url;
            $css_content = $element->get_first_child->get_text_content;
        }
        else {
            # <link rel="stylesheet" type="text/css" href="">
            my $href = $element->get_attribute('href');
            ($css_content, $base_url) = get_content($href, $doc_url, $resources) or next;
        }

        parse_css_rules($css_content, $base_url, $resources, \%selectors);
    }

    return \%selectors;
}


sub parse_css_rules {
    my ($css_content, $base_url, $resources, $selectors) = @_;
    my $css = CSS::DOM::parse($css_content);
    my $rules = 0;
    foreach my $rule ($css->cssRules) {
        ++$rules;
        if ($rule->isa('CSS::DOM::Rule::Import')) {
            my $href = $rule->href;
            print "\@import $href\n" if $VERBOSE;
            my ($content, $url) = get_content($href, $base_url, $resources) or next;
            parse_css_rules($content, $url, $resources, $selectors);
        }
        elsif ($rule->isa('CSS::DOM::Rule')) {
            foreach my $selectorText (split /\s*,\s*/, $rule->selectorText) {
                $selectors->{$selectorText} = {
                    count    => 0,
                    selector => $selectorText,
                    rule     => $rule,
                    url      => $base_url,
                };
            }
        }
        else {
            #FIXME implement other rules (@media)
            print "Skipping CSS entry $rule\n";
            next;
        }
    }
    print "Loaded $rules rules from $base_url\n";
}


sub get_content {
    my ($url, $base_url, $resources) = @_;
    my $full_url = URI->new_abs($url, $base_url)->as_string;
    my $content = $resources->{$full_url};
    if (!$content) {
        print "*** Missing content for $full_url\n";
        print "Available content: ", Dumper([ keys %$resources ]);
    }
    return ($content, $full_url);
}


exit main() unless caller;
