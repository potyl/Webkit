#!/usr/bin/env perl


use strict;
use warnings;

use Data::Dumper;
use Dancer;
use DBI;

set logger => 'console';


my $dbh = DBI->connect('dbi:SQLite:dbname=queue.db', '', '');
$dbh->do(qq{
    CREATE TABLE IF NOT EXISTS queue (
        id     INTEGER PRIMARY KEY AUTOINCREMENT,
        url    TEXT NOT NULL,
        size   TEXT NOT NULL DEFAULT '1280x800',
        type   TEXT NOT NULL DEFAULT 'png',
        proxy  TEXT NOT NULL DEFAULT '',
        xpath  TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'pending'
    );
});

get '/' => sub {

    my $url = param('url') // '';
    my $id = param('id') // 0;
    my $size = param('size') // '1280x800';
    my $proxy = param('proxy') // '';
    my $xpath = param('xpath') // '';

    my $select = $dbh->prepare("SELECT * FROM queue");
    $select->execute();

    my $out = qq{
        <html>
            <head><title>Screen capture queue</title></head>
            <body>
            <h1>Urls to download</h1>
            <table>
            <tr>
                <th>Id</th>
                <th>Url</th>
                <th>Resolution</th>
                <th>Extension</th>
                <th>Proxy</th>
                <th>XPath</th>
                <th>Status</th>
                <th>Action</th>
            </tr>
    };
    while (my $row = $select->fetchrow_hashref) {
        my $id_text = $row->{id};
        $id_text = "<b>*</b> $id_text" if $row->{id} == $id;
        my $status_text = $row->{status};
        if ($status_text eq 'done') {
            $status_text = qq{<a href="view?id=$row->{id}">$status_text</a>};
        }

        $out .= qq{
            <tr>
                <td>$id_text</td>
                <td><a href="$row->{url}">$row->{url}</a></td>
                <td>$row->{size}</td>
                <td>$row->{type}</td>
                <td>$row->{proxy}</td>
                <td>$row->{xpath}</td>
                <td>$status_text</a></td>
                <td><a href="/delete?id=$row->{id}">Delete</a></td>
            </tr>
        };
    }

    $out .= qq{
            </table>

            <hr/>

            <form action="/add">
            <table>
                <tr>
                    <th>Url:</th>
                    <td>
                        <input type="text" name="url" value="$url" size="80"/>
                    </td>
                </tr>

                <tr>
                    <th>Size:</th>
                    <td>
                        <input type="text" name="size" value="$size" size="10"/> (ex: 1280x800)
                    </td>
                </tr>

                <tr>
                    <th>Type:</th>
                    <td>
                        <input type="radio" name="type" id="png" value="png" checked/> <label for="png">PNG</label> &nbsp; &nbsp;
                        <input type="radio" name="type" id="pdf" value="pdf"/> <label for="pdf">PDF</label>
                    </td>
                </tr>

                <tr>
                    <th>Proxy:</th>
                    <td>
                        <input type="text" name="proxy" value="$proxy" size="80"/>
                    </td>
                </tr>

                <tr>
                    <th>XPath:</th>
                    <td>
                        <input type="text" name="xpath" value="$xpath" size="80"/>
                    </td>
                </tr>

                <tr>
                    <td colspan="2"><input type="submit" value="Add"/>
                </tr>
            </table>
            </form>

            </body>
        </html>
    };

    return $out;
};


get '/add' => sub {
    my $url = param('url') or return do_error("Missing parameter 'url'");
    my $size = param('size') // '';
    my $type = param('type') // 'png';
    my $proxy = param('proxy') // '';
    my $xpath = param('xpath') // '';

    foreach my $val ($url, $size, $type, $proxy, $xpath) {
        $val = trim($val);
    }

    $dbh->begin_work();

    my $id = '';
    eval {
        $dbh->do(
            "INSERT INTO queue (url, size, type, proxy, xpath) VALUES (?, ?, ?, ?, ?)",
            undef,
            $url, $size, $type, $proxy, $xpath,
        );
        $id = $dbh->sqlite_last_insert_rowid();
        $dbh->commit();
        1;
    } or do {
        my $error = $@ || "Internal error";
        warn "Error: $error";
        $dbh->rollback();
        return send_error "Server error";
    };

    return redirect "/?id=$id";
};


get '/delete' => sub {
    my $id = param('id') or return do_error("Missing parameter 'id'");

    $dbh->begin_work();

    eval {
        $dbh->do("DELETE FROM queue WHERE id = ?", undef, $id);
        $dbh->commit();
        1;
    } or do {
        my $error = $@ || "Internal error";
        warn "Error: $error";
        $dbh->rollback();
        return send_error "Server error";
    };

    return redirect "/";
};

my %MIME_TYPES = (
    pdf => 'application/pdf',
    png => 'image/png',
);
get '/view' => sub {
    my $id = param('id') or return do_error("Missing parameter 'id'");
 
    my $select = $dbh->prepare("SELECT type FROM queue WHERE id = ? LIMIT 1");
    $select->execute($id);
    while (my $row = $select->fetchrow_hashref) {
        my $type = $row->{type} || 'png';
        my $file = "captures/$id.$type";
        my $mime_type = $MIME_TYPES{$type};
        debug "Showing $file ($mime_type)";
        return do_error("Can't find the file $file") unless -e $file;
        return send_file $file, content_type => $mime_type, system_path => 1;
    }

    return do_error("Can't find screenshot with id: $id");
};


sub do_error {
    my ($message) = @_;
    return qq{
        <html>
        <body>
        <h1>Error</h1>
        <p>$message</p>
        </body>
        </html>
    };
}


sub trim {
    my ($string) = @_;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}


dance();
