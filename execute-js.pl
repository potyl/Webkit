#!/usr/bin/env perl

=head1 NAME

execute-js.pl - Execute javascript in webkit

=head1 SYNOPSIS

Simple usage:

    execute-js.pl http://www.google.com/

=head1 DESCRIPTION

Display a web page and execute javascript on the page.

=cut

use strict;
use warnings;

use Glib qw(TRUE FALSE);
use Gtk2 -init;
use WWW::WebKit;
use Data::Dumper;
use Cairo;


sub main {
    my ($url) = @ARGV;
    $url ||= 'http://localhost:3001/';

    my $window = Gtk2::Window->new('toplevel');
    my $screen = $window->get_screen;

    $window->set_default_size(800, 600);
    $window->signal_connect(destroy => sub { Gtk2->main_quit() });

    my $view = WWW::WebKit::WebView->new();
    my $button = Gtk2::Button->new("Execute");
    my $entry = Gtk2::Entry->new();

    # Execute the javascript when the user wants it
    $button->signal_connect(clicked => \&execute_js, [$view, $entry]);
    $entry->signal_connect(activate => \&execute_js, [$view, $entry]);


    # Pack the widgets together
    my $sw = Gtk2::ScrolledWindow->new();
    $sw->add($view);
    my $hbox = Gtk2::HBox->new(0, 0);
    $hbox->pack_start($entry, TRUE, TRUE, 2);
    $hbox->pack_start($button, FALSE, FALSE, 2);

    my $box = Gtk2::VBox->new(0, 0);
    $box->pack_start($hbox, FALSE, FALSE, 2);
    $box->pack_start($sw, TRUE, TRUE, 2);


    $window->add($box);
    $window->show_all();

    $view->open($url);

    Gtk2->main;
    return 0;
}


sub execute_js {
    my $data = pop @_;
    my ($view, $entry) = @{ $data };
    my $js = $entry->get_text;
    $view->execute_script($js);
}


exit main() unless caller;
