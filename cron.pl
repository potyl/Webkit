#!/usr/bin/env perl


use strict;
use warnings;

use DBI;


sub main {
    my $dbh = DBI->connect('dbi:SQLite:dbname=queue.db', '', '');

    my $update = $dbh->prepare("UPDATE queue SET status = ? WHERE id = ?");

    $dbh->begin_work();

    my $select = $dbh->prepare("SELECT * FROM queue WHERE status = 'pending' LIMIT 1");
    $select->execute();
    while (my $row = $select->fetchrow_hashref) {
        my $id = $row->{id};
        my $url = $row->{url};

        print "Marking $id as downloading\n";
        $update->execute('downloading', $id);
        $dbh->commit();

        print "Capturing $url as $id.png\n";

        my @command = (
            './screenshot.pl', $url,
            '--output', "captures/$id.$row->{type}",
        );
        foreach my $field ( qw(size type proxy xpath pause) ) {
            my $value = $row->{$field};
            push @command, "--$field", $value if $value;
        }

        print "Running @command\n";
        my $exit = system @command;
        my $status = $exit == 0 ? 'done' : 'error';
        print "Marking $id as $status\n";
        $update->execute($status, $id);
    }

    $dbh->disconnect();


    return 0;
}


exit main() unless caller;
