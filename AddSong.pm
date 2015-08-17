#!/usr/bin/env perl

use Modern::Perl 2012;

package AddSong;

use strict;
use warnings;
use utf8;

use HTML::TreeBuilder;
use DBI;
use LWP::UserAgent;
use JSON;
use Data::Dumper;

my $user_agent = "";

my $jellyApi = "http://www.jellynote.com/api/v1.1/";

sub new
{
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;

	my $db = DBI->connect("dbi:SQLite:dbname=db/jelly.db","","");
	$db->{sqlite_unicode} = 1;

        my $browser = LWP::UserAgent->new(
            agent => $user_agent,
            timeout => 300);

	my $self = {
	_db => $db,
        _browser => $browser,
	_q_ins_artist => $db->prepare("INSERT INTO ARTIST VALUES(?, ?, ?)"),
	_q_ins_song => $db->prepare("INSERT INTO SONG VALUES(?, ?, ?)"),
	_q_ins_track => $db->prepare("INSERT INTO TRACK VALUES(?, ?, ?, ?, ?, ?)"),
        _q_sel_score => $db->prepare("SELECT ID FROM SCORE WHERE JELLY_SCORE_ID = ?"),
        _q_ins_score => $db->prepare("INSERT INTO SCORE VALUES(?, ?, ?)"),
        _q_ins_chord => $db->prepare("INSERT INTO CHORD VALUES(?, ?, ?)"),
        _q_sel_arti_id => $db->prepare("SELECT ID FROM ARTIST WHERE NAME = ?"),
        _q_sel_all_arti => $db->prepare("SELECT * FROM ARTIST"),
	};

	bless($self, $class);
	return $self;
}

sub _get_object
{
    my ($self, $url) = @_;

    my $response = $self->{_browser}->get($url);

    while (!$response->is_success)
    {
        say "$response->{status_line}";
        $response = $self->{_browser}->get($url);
    }

    return decode_json($response->decoded_content); 
}

sub process_url
{
    my ($self, $url) = @_;

    my $response = $self->{_browser}->get($url);

    my $tree = HTML::TreeBuilder->new;

    $tree->ignore_unknown(0);
    $tree->parse($response->decoded_content) or next;
    $tree->eof();
    
    my $article = $tree->look_down(_tag => "article", class => "score-view ");

    if (!defined $article)
    {
        print "No score was found there.\n";
        return;
    } 

    my $song = ($tree->look_down(_tag => "h1", itemprop => "name"))->as_text;
    my $arti = ($tree->look_down(_tag => "h2", class => "artist"))->as_text;
    my $id = $article->attr("data-scoreid");

    print "Artist: $arti\n";
    print "Song name: $song\n";
    print "Score ID: $id\n";

    my $dup = $self->score_exists($id);
    print "Already in DB: $dup\n";
    return if $dup;

    my $arti_id = $self->addArtist($arti);
    my $song_id = $self->addSong($song, $arti_id, $id);

    for (my $i = 0; $i < 27; $i++)
    {
        my $c = chr(ord('A') + $i);
	my $track_id = "score_${c}";
        my $name = "${track_id}_data";
        my $instr = "${track_id}_instr";

        for my $subtree ($tree->look_down(_tag => "textarea", id => $name))
        {
            my $midi_instr = ($tree->look_down(_tag => "input", id => $instr));
            $midi_instr = $midi_instr->attr("value");

            my $data = $subtree->as_text;
            print "score block: $name\n";

	    my $track_name = $tree->look_down('data-trackid' => "#$track_id")
		->look_down(_tag => 'div', class => 'trackname')->as_text;
	
	    $self->addTrack($track_name, $midi_instr, $song_id, $data);
        }
    }

    $tree = $tree->delete;
}

sub score_exists
{
    my ($self, $id) = @_;

    (my $r) = $self->{_db}->selectrow_array(
        "SELECT COUNT(*) FROM SONG WHERE JELLY_TRACK_ID = '$id'");
    return $r;
}

sub addArtist
{
    my ($self, $arti, $jelly_arti_id) = @_;

    $self->{_q_ins_artist}->execute($jelly_arti_id, undef, $arti);

    $self->{_q_sel_arti_id}->execute($arti);
    my ($arti_id) = $self->{_q_sel_arti_id}->fetchrow_array();
    return $arti_id;
}

sub addSong
{
    my ($self, $song, $arti_id, $song_id) = @_;

    $self->{_q_ins_song}->execute($song, $arti_id, $song_id);
}

sub addScore
{
    my ($self, $jelly_scor_id, $song_id) = @_;

    $self->{_q_sel_score}->execute($jelly_scor_id);
    my ($id) = $self->{_q_sel_score}->fetchrow_array();
    return $id if defined $id;

    $self->{_q_ins_score}->execute(undef, $jelly_scor_id, $song_id);
    $self->{_db}->func('last_insert_rowid');
}

sub addTrack
{
    my ($self, $volume, $score_id, $track_name, $midi_instr, $data) = @_;

    $self->{_q_ins_track}->execute(
        $volume, $score_id, $track_name, $midi_instr, undef, $data);

    print "track: $track_name, midi: $midi_instr\n";
}

sub addChords
{
    my ($self, $score_id, $chords) = @_;

    $self->{_q_ins_chord}->execute(
        undef, $score_id, $chords);
}

sub buildArtistList
{
    my ($self) = @_;

    my $url = "$jellyApi/artist/?limit=9999&sort=name&letter=";

    for (my $l = ord('A'); $l <= ord('Z'); $l++)
    {
        my $c = chr($l);
	my $response = decode_json(
            $self->{_browser}->get($url . $c)->decoded_content);

        for my $obj (@{$response->{objects}})
        {
            $obj->{resource_uri} =~ /(\d+)\/$/;
            my $arti_id = $1;
            #print "$obj->{name}\n";
            $self->addArtist($obj->{name}, $arti_id);
        }
    }
}

sub buildSongList
{
    my ($self) = @_;

    $self->{_q_sel_all_arti}->execute;

    while (my @row = $self->{_q_sel_all_arti}->fetchrow_array)
    {
        print "@row\n";
        my $arti_id = $row[0];
        my $url = "$jellyApi/artist/$arti_id/songs/?limit=9999";
        my $songs = $self->_get_object($url);

        foreach my $song (@{$songs->{objects}})
        {
            $song->{resource_uri} =~ /(\d+)\/$/;
            my $song_id = $1;

            $self->addSong(
                $song->{name},
                $arti_id,
                $song_id);

            my $url = "$jellyApi/song/$song_id/scores/?limit=9999";
            my $scores = $self->_get_object($url);

            foreach my $score (@{$scores->{objects}})
            {
                my $score_id = $self->addScore(
                    $score->{id},
                    $song_id);

                my $url = "$jellyApi/score/$score->{id}";
                my $tracks = $self->_get_object($url);

                foreach my $track (@{$tracks->{tracks}})
                {
                    $self->addTrack(
                        $track->{volume},
                        $score_id,
                        $track->{title},
                        $track->{midi},
                        $track->{score});
                }

                if (defined $tracks->{chords})
                {
                    $self->addChords(
                        $score_id,
                        $tracks->{chords});
                }
            }
        }
    }
}

sub scoreDataById
{
	my ($self, $id) = @_;
	my $url = "$jellyApi/score/$id";
	return $self->_get_object($url);
}

sub DESTROY
{
	my ($self) = @_;
	$self->{_db}->disconnect;
}
