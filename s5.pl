#!/usr/bin/env perl

=head1 NAME

s5.pl - Convert an S5 presentation to PDF

=head1 SYNOPSIS

s5.pl [OPTION]... [URI [FILE]]

    -h, --help             print this help message

Simple usage:

    s5.pl --type svg s5-presentation.html

=head1 DESCRIPTION

Convert and s5 presentation into a PDF.

=cut

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long qw(:config auto_help);
use Pod::Usage;
use URI;

use Glib::Object::Introspection;
Glib::Object::Introspection->setup(
  basename => 'Gtk',
  version  => '3.0',
  package  => 'Gtk3'
);

Glib::Object::Introspection->setup(
  basename => 'WebKit',
  version  => '3.0',
  package  => 'WebKit'
);
use Cairo::GObject;
use constant TRUE  => 1;
use constant FALSE => 0;

sub main {
    Gtk3::init(0, []);

    GetOptions() or podusage(1);
    my ($uri, $filename) = @ARGV or podusage(1);
    $uri = "file://$uri" if -e $uri;
    $filename ||= "s5.pdf";
    my $filename_pattern = $filename;
    $filename_pattern =~ s/\.pdf$//;
    my $filename_i = 1;

    my $view = WebKit::WebView->new();
    my $i = 0;
    $view->signal_connect('notify::load-status' => sub {
        return unless $view->get_uri and ($view->get_load_status eq 'finished');

        # We take a screenshot now
        # Sometimes the program dies with:
        #  (<unknown>:19092): Gtk-CRITICAL **: gtk_widget_draw: assertion `!widget->priv->alloc_needed' failed
        # This seem to happend is there's a newtwork error and we can't download
        # external stuff (e.g. facebook iframe). This timeout seems to help a bit.
        Glib::Idle->add( sub {
            $view->execute_script(q{ _is_end_of_slides(); });
        });
    });
    $view->load_uri($uri);


    $view->signal_connect('console-message' => sub {
        my ($widget, $message, $line, $source_id) = @_;
        print "CONSOLE $message at $line $source_id\n";
#if ($i > 20) {print "too many calls\n"; exit 1;}
        my ($end) = ( $message =~ /^s5-end-of-slides: (true|false)$/) or return TRUE;

        if ($end eq 'true') {
            Gtk3->main_quit();
        }
        else {
            # A new slide has been rendered on screen
            $filename = sprintf "%s-%d.pdf", $filename_pattern, $filename_i++;
            print "PDF: $filename\n";
            save_as_pdf($view, $filename);
$i++;
            # Go on with the slide
            $view->execute_script(q{ _next_slide(); });
        }

        return TRUE;
    });

    $view->execute_script(q{
        function _is_end_of_slides () {
            var last_slide = (snum == smax - 1) ? true : false;
            var last_subslide = ( !incrementals[snum] || incpos >= incrementals[snum].length ) ? true : false;
            var ret = (last_slide && last_subslide) ? true : false ;
            console.log("last_slide: " + last_slide + "; last_subslide: " + last_subslide + "; fini: " + ret);
            console.log("end? " +  (  (snum == smax - 1) && ( !incrementals[snum] || incpos >= incrementals[snum].length ) ));
            console.log("s5-end-of-slides: " + ret);
            return ret;
        }

        function _next_slide () {
            console.log("Next slide (snum:" + snum + "; incpos: " + incpos + ") ?");
            if (!incrementals[snum] || incpos >= incrementals[snum].length) {
                console.log("go(1)");
                go(1);
            }
            else {
                console.log("subgo(1)");
                subgo(1);
            }
            
            console.log("s5-end-of-slides: " + true);
            _is_end_of_slides();
        }

    });

#    my $window = Gtk3::OffscreenWindow->new();
    my $window = Gtk3::Window->new('toplevel');
    $window->set_default_size(600, 400);
    $window->add($view);
    $window->show_all();

    Gtk3->main();
    return 0;
}


sub save_as_pdf {
    my ($widget, $filename) = @_;

    my ($width, $height) = ($widget->get_allocated_width, $widget->get_allocated_height);
    print "$filename has size: $width x $height\n";
    my $surface = Cairo::PdfSurface->create($filename, $width, $height);
    my $cr = Cairo::Context->create($surface);
    $widget->draw($cr);
}

exit main() unless caller;
