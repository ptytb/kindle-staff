#!/usr/bin/perl

use Modern::Perl 2018;
use strict;
use warnings;

use DBI;
use Tk;
use Tk::TableMatrix;
use Tk::TableMatrix::Spreadsheet;
use experimental qw( switch );

use lib '.';
use generate qw(generate);

my $db = DBI->connect("dbi:SQLite:dbname=db/jelly.db","","");
$db->{sqlite_unicode} = 1;

my $q_sel_artist = $db->prepare("SELECT JELLY_ARTIST_ID, NAME FROM ARTIST");
my $q_sel_song = $db->prepare("SELECT ID, NAME FROM SONG WHERE ARTIST_ID = ?");
my $q_sel_score = $db->prepare("SELECT ID, JELLY_SCORE_ID FROM SCORE WHERE SONG_ID = ?");

my $data = {};
my $state = 1;

my $song_id;

my $mw = MainWindow->new;

my $table = $mw->Scrolled("Spreadsheet",
-drawmode => 'slow',
-titlecols => 0,
-titlerows => 0,
-selecttitles => 0,
-rows => 0,
-cols => 2,
-colstretchmode=>'all',
-sparsearray => 0,
-cache => 0,
-scrollbars => "osoe",
-selectmode => 'extended',
-selecttype => 'row',
-variable => $data,
)->pack(-expand => 1, -fill => 'both');

$table->bind('<Double-1>', \&action);
$mw->geometry('800x600');
$mw->update;
my $xpos = int(($mw->screenwidth  - $mw->width ) / 2);
my $ypos = int(($mw->screenheight - $mw->height) / 2);
$mw->geometry("+$xpos+$ypos");
&menu($q_sel_artist);
MainLoop;

sub action
{
    my $row = ($table->curselection)[0];
    return if !defined $row;
    $row =~ s/,.*//;

    my $index = $data->{"$row,0"};
    print "$index\n";

    given ($state)
    {
        when (0) {
            menu($q_sel_artist);
            $state = 1;
        }

        when (1) {
            menu($q_sel_song, $index);
            $state = 2;
        }

        when (2) {
            $song_id = $index;
            menu($q_sel_score, $index);
            $state = 3;
        }

        when (3) {
            $mw->destroy;
            my $score_id = $index;
            generate($song_id, $score_id);
            # system "perl ./generate.pl $song_id $score_id";
            exit;
        }
    }
}

sub menu
{
    my ($query, $index) = @_;

    $table->configure(-state => 'normal');
    $table->deleteRows(0, $table->cget(-rows));

    if (defined($index)) {
        $query->execute($index);
    } else {
        $query->execute();
    }

    my $r = 0;
    while (my @row = $query->fetchrow_array())
    {
    $data->{"$r,0"} = $row[0];
    $data->{"$r,1"} = $row[1];
    ++$r;
    }

    $table->configure(-rows => $r, -state => 'disabled');
}
