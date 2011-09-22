#!/usr/bin/env perl

=head1 NAME

css-rules-usage.pl - Reports the usage of CSS rules

=head1 SYNOPSIS

dom.pl [OPTION]... [URI]

    -d, --debug            turn on debug mode
    -v, --verbose          turn on verbose mode
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

use CSS::DOM;

use constant DOM_TYPE_ELEMENT => 1;


my $DEBUG = 0;
my $VERBOSE = 0;


sub main {
    Gtk3::init();

    GetOptions(
        'save|s'    => \my $save,
        'debug|d'   => \$DEBUG,
        'verbose|v' => \$VERBOSE,
    ) or podusage(1);

    my ($url) = @ARGV;
    $url ||= 'http://localhost:3001/';

    my $view = Gtk3::WebKit::WebView->new();
    $view->signal_connect('notify::load-status' => sub {
        return unless $view->get_uri and ($view->get_load_status eq 'finished');
        print "Document loaded\n";

        if ($save) {
            my $file = 'page.html';
            open my $handle, '>:encoding(UTF-8)', $file or die "Can't write to $file: $!";
            print $handle $view->get_focused_frame->get_data_source->get_data->{str};
            close $handle;
        }

        report_selectors_usage($view->get_dom_document);
        Gtk3->main_quit();
    });
    $view->load_uri($url);

    my $window = Gtk3::OffscreenWindow->new();
    $window->add($view);
    $window->show_all();

    Gtk3->main();
    return 0;
}


sub report_selectors_usage {
    my ($doc) = @_;

    # Get the RAW defition of the CSS (need to parse CSS text in order to extract the rules)
    my $styles = $doc->get_elements_by_tag_name('style');
    # FIXME get the rules from the <link type="text/css" rel="stylsheet">
    my %selectors;
    my $length = $styles->get_length;
    printf "Found $length style elements\n";
    for (my $i = 0; $i < $length; ++$i) {
        my $css_content = $styles->item($i)->get_first_child->get_text_content;
        my $css = CSS::DOM::parse($css_content);
        my $rules = 0;
        foreach my $rule ($css->cssRules) {
            ++$rules;
            foreach my $selectorText (split /\s*,\s*/, $rule->selectorText) {
                $selectors{$selectorText} = {
                    count    => 0,
                    selector => $selectorText,
                    rule     => $rule,
                };
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
