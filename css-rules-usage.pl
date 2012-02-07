#!/usr/bin/env perl

=head1 NAME

css-rules-usage.pl - Reports the usage of CSS rules

=head1 SYNOPSIS

dom.pl [OPTION]... [URI]

    -t, --trace            turn on trace mode
    -d, --debug            turn on debug mode
    -v, --verbose          turn on verbose mode
        --exit             quit with exit instead of stopping the main loop
    -s, --save FILE        save the input file as FILE
    -m, --media MEDIA      the CSS media type being handled
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
use Gtk3 -init;
use Gtk3::WebKit qw(:xpath_results :node_types);
use HTTP::Soup;

use CSS::DOM;
use URI;
use POSIX qw(_exit);
use Time::HiRes qw(time);


my $TRACE = 0;
my $DEBUG = 0;
my $VERBOSE = 0;
my $MEDIA;


sub main {
    GetOptions(
        'save|s=s'  => \my $save,
        'media|m=s' => \$MEDIA,
        'trace|t'   => \$TRACE,
        'debug|d'   => \$DEBUG,
        'verbose|v' => \$VERBOSE,
        'exit'      => \my $do_exit,
    ) or pod2usage(1);

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

    my $start;
    $view->signal_connect('notify::load-status' => sub {
        return unless $view->get_uri and ($view->get_load_status eq 'finished');
        Glib::Idle->add(sub {
            # Wait until all CSS files are loaded
            return 1 unless $requests_started and $requests_started == $requests_finished;
            printf "All resources loaded ($requests_started/$requests_finished) in %0.2fs\n", (time() - $start);

            my $list = $view->get_focused_frame->get_data_source->get_subresources;
            my %resources;
            foreach my $resource (@$list) {
                my $data = $resource->get_data;
                next unless defined $data;
                my $uri = $resource->get_uri or next;
                $resources{$uri} = $data;
            }

            if (defined $save) {
                my $file = $save;
                open my $handle, '>:encoding(UTF-8)', $file or die "Can't write to $file: $!";
                print $handle $view->get_focused_frame->get_data_source->get_data->{str};
                close $handle;
            }

            my $now = time();
            report_selectors_usage($view->get_dom_document, \%resources);
            printf "Document processed in %0.2fs\n", (time() - $now);
            if ($do_exit) {
                # Prevents the seg fault at the cleanup in an unstable WebKit version
                _exit(0);
            }
            else {
                Gtk3->main_quit();
            }
        }) ;
    });

    # Hide JavaScript console messages
    $view->signal_connect('console-message' => sub { return TRUE; });

    $view->load_uri($url);

    my $window = Gtk3::OffscreenWindow->new();
    $window->add($view);
    $window->show_all();

    $start = time();
    Gtk3->main();
    return 0;
}


sub report_selectors_usage {
    my ($doc, $resources) = @_;

    # Get the RAW defition of the CSS (need to parse CSS text in order to extract the rules)
    my $start = time();
    $DB::single = 1;
    my $selectors = get_css_rules($doc, $resources);
    printf "Found %d selectors in %.2fs\n", scalar(keys %$selectors), time() - $start;

    $start = time();
    my $count = walk_dom($doc->get_body, $selectors);
    printf "Traversed %d DOM elements in %.2fs\n", $count, time() - $start;

    my @selectors = sort {
           $b->{count} <=> $a->{count}
        || $a->{selector} cmp $b->{selector}
    } values %$selectors;

    my $unused = 0;
    foreach my $selector (@selectors) {
        my $count = $selector->{count};
        printf "Selector %s matches %d elements (%s)\n",
            $selector->{selector},
            $count,
            $selector->{url},
            if ($VERBOSE and $count == 0) or $DEBUG;
        ++$unused if $count == 0;
    }
    print "Found $unused unused selectors\n";
}


sub walk_dom {
    my ($node, $selectors) = @_;

    if ($node->get_node_type == ELEMENT_NODE) {
        foreach my $selector (keys %$selectors) {
            my $matches = $node->webkit_matches_selector($selector);
            ++$selectors->{$selector}{count} if $matches;
            printf "Element %s matches %s? %s\n", $node->get_tag_name, $selector, $matches ? 'TRUE' : 'FALSE' if $TRACE;
        }
    }

    my $count = 1;
    my $child_nodes = $node->get_child_nodes;
    for (my ($i, $l) = (0, $child_nodes->get_length); $i < $l; ++$i) {
        my $child = $child_nodes->item($i);
        $count += walk_dom($child, $selectors);
    }

    return $count;
}


sub get_css_rules {
    my ($doc, $resources) = @_;

    my %selectors;

    # Get the RAW defition of the CSS (need to parse CSS text in order to extract the rules)
    my $resolver = $doc->create_ns_resolver($doc);
    my $xpath_results = $doc->evaluate(
        '//style | //link[@rel = "stylesheet" and @type="text/css" and @href]',
        $doc,
        $resolver,
        ORDERED_NODE_SNAPSHOT_TYPE,
        undef,
    );
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


        my $css_dom = CSS::DOM::parse(
            $css_content,
            url_fetcher => sub {
                my ($url) = @_;
                print "URL: $url\n";
                my $uri = URI->new_abs($url, $base_url);
                print "URI: $uri\n";
                return;# fixme return the content
            },
        );
$DB::single = 1;
        parse_css_rules($css_dom, \%selectors);
    }

    return \%selectors;
}


sub parse_css_rules {
    my ($css_dom, $selectors) = @_;

    my $rules = 0;
    foreach my $rule ($css_dom->cssRules) {
        ++$rules;
        if ($rule->isa('CSS::DOM::Rule::Import')) {
            my $href = $rule->href;
            print "\@import $href\n" if $VERBOSE;
            my $dom_style_sheet = $rule->styleSheet; # Force scalar context
            parse_css_rules($dom_style_sheet, $selectors) if is_wanted_media($rule);
        }
        elsif ($rule->isa('CSS::DOM::Rule::Media')) {
            printf "Handling '\@media %s\n", $rule->media;
            parse_css_rules($rule, $selectors) if is_wanted_media($rule);
        }
        elsif ($rule->isa('CSS::DOM::Rule')) {
            foreach my $selectorText (split /\s*,\s*/, $rule->selectorText) {
                $selectors->{$selectorText} = {
                    count    => 0,
                    selector => $selectorText,
                    rule     => $rule,
                    #url      => $base_url,
                };
            }
        }
        else {
            print "Skipping CSS entry $rule\n";
            next;
        }
    }
    print "Loaded $rules rules from $css_dom\n";
}


sub is_wanted_media {
    my ($rule) = @_;
    my @media = map { lc $_ } $rule->media or return 1;
    foreach my $media (@media) {
        return 1 if $media eq $MEDIA;
    }
    return;
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
