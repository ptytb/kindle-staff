#!/usr/bin/env perl

use Modern::Perl 2012;
use strict;
use warnings;
use utf8;

use HTML::TreeBuilder;
use LWP::UserAgent;
use JSON;
use Data::Dumper;

use AddSong;

my $user_agent = "Mozilla/5.0 (X11; Linux i686; rv:34.0) Gecko/20100101 Firefox/34.0 Iceweasel/34.0";

my $browser = LWP::UserAgent->new(agent => $user_agent);

my $song = AddSong->new();

sub songUrls
{
	my $url = shift;
	my $response = $browser->get($url);

	my $tree = HTML::TreeBuilder->new;
	$tree->ignore_unknown(0);
	$tree->parse($response->decoded_content) or die "$!";
	$tree->eof();

	my $songList = $tree->look_down(_tag => "ul", class => "songlist");

        for my $songItem ($songList->look_down(_tag => "li",
		class => "details collapse"))
	{ 
		my $id = $songItem->attr("data-songid");
		next if !defined $id;

		print "Found song id $id\n";

		my $info = songInfoById($id);
		#print Dumper($info);

		map {
			addSongByInfo($_);
			#$song->process_url("http://jellynote.com" . $_->{url});
		} @{$info->{objects}};
	}

}

my $jellyApi = "https://www.jellynote.com/api/v1.1/";
my $getScoresParams = "/scores/?format=jsonp";

sub songInfoById
{
	my $id = shift;
	my $url = "$jellyApi/song/$id$getScoresParams";
	return decode_json($browser->get($url)->decoded_content);
}

sub scoreDataById
{
	my $id = shift;
	my $url = "$jellyApi/score/$id";
	return decode_json($browser->get($url)->decoded_content);
}

sub addSongByInfo
{
	my ($info) = @_;

	my $dup = $song->score_exists($info->{id});
	print "Already in DB: $dup\n";
	return if $dup;

	my $score = scoreDataById($info->{id});
	
	my $arti_id = $song->addArtist($info->{artist_name},
                                       $info->{artist_id});

	my $song_id = $song->addSong($info->{song_name}, $arti_id, $info->{id},
                                     $info->{song_id});
	
	foreach my $track (@{$score->{tracks}})
	{
		my $midi_instr = (grep { $_->[0] eq $track->{id} }
			@{$info->{tracks_preview}})[0][2];

		$song->addScore($track->{title}, $midi_instr, $song_id,
			$track->{score});
	}
}

#map { songUrls $_ } @ARGV;


#buildArtistList;

$song->buildArtistList();
$song->buildSongList();

