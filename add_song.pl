#!/usr/bin/env perl

use Modern::Perl 2012;
use strict;
use warnings;
use utf8;

use Tk;
use Tk::DialogBox;
use Tk::Entry;

use AddSong;

my $song = AddSong->new();

if (scalar @ARGV > 0)
{
    foreach my $url (@ARGV) {
        $song->process_url($url);
    }
}
else
{
    my $w = new MainWindow;
    $w->withdraw();
    $w->update();

    my $input;
    my $callback = sub {
        exit if shift ne 'OK';
        $song->process_url($input) if defined $input;
        exit;
    };

    my $d = $w->DialogBox(-title => 'Add song by url',
                          -buttons => ["OK", "Cancel" ],
                          -command => $callback);
    $d->Entry(-textvariable => \$input)->pack;

    $d->Show;
    MainLoop;
}
